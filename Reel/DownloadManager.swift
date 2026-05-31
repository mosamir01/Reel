import Foundation
import AppKit
import AVFoundation

@MainActor
class DownloadManager: ObservableObject {
    @Published var items: [DownloadItem] = []
    @Published var outputFolder: URL? = nil      // nil until user picks on first launch
    @Published var needsFolderSetup = false

    private let maxConcurrent = 3
    private let folderKey = "reelOutputFolder"

    init() {
        if let data = UserDefaults.standard.data(forKey: folderKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                outputFolder = url
            }
        }
        needsFolderSetup = (outputFolder == nil)
    }

    func pickOutputFolder(completion: ((URL?) -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Download Folder"
        panel.message = "Where should Reel save downloaded media?"
        if panel.runModal() == .OK, let url = panel.url {
            saveFolder(url)
            completion?(url)
        } else {
            completion?(nil)
        }
    }

    private func saveFolder(_ url: URL) {
        outputFolder = url
        needsFolderSetup = false
        if let data = try? url.bookmarkData(options: .withSecurityScope) {
            UserDefaults.standard.set(data, forKey: folderKey)
        }
    }

    func add(url: String, format: DownloadFormat, quality: VideoQuality = .best) {
        guard let folder = outputFolder else { needsFolderSetup = true; return }
        _ = folder   // silence unused warning
        let clean = url.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        let item = DownloadItem(url: clean, format: format, quality: quality)
        items.insert(item, at: 0)
        processQueue()
    }

    func cancel(_ item: DownloadItem) {
        item.process?.terminate()
        items.removeAll { $0.id == item.id }
        processQueue()
    }

    func remove(_ item: DownloadItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearCompleted() {
        items.removeAll {
            switch $0.status { case .done, .failed: return true; default: return false }
        }
    }

    func openFile(_ item: DownloadItem) {
        if let path = item.filePath {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else if let folder = outputFolder {
            NSWorkspace.shared.open(folder)
        }
    }

    func openOutputFolder() {
        guard let folder = outputFolder else { return }
        NSWorkspace.shared.open(folder)
    }

    private func activeCount() -> Int { items.filter { $0.status.isActive }.count }

    private func processQueue() {
        let active = activeCount()
        guard active < maxConcurrent else { return }
        let queued = items.filter { if case .queued = $0.status { return true }; return false }
        for item in queued.prefix(maxConcurrent - active) {
            Task { await startDownload(item) }
        }
    }

    private func startDownload(_ item: DownloadItem) async {
        guard let folder = outputFolder else { item.status = .failed("No output folder selected."); return }
        guard let ytdlp = findBin("yt-dlp") else {
            item.status = .failed("yt-dlp not found.\nRun in Terminal: brew install yt-dlp")
            return
        }

        item.status = .fetching

        // Video formats download the separate video + audio streams into a temp
        // directory and merge them locally with AVFoundation — no external binary.
        // Audio formats download a single stream straight to the output folder.
        let temp: URL? = item.format.isVideo
            ? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("reel-\(item.id.uuidString)", isDirectory: true)
            : nil
        if let temp { try? FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true) }
        let destDir = temp ?? folder
        let template = item.format.isVideo ? "%(title)s.%(format_id)s.%(ext)s" : "%(title)s.%(ext)s"

        var args: [String] = [
            "--newline", "--progress", "--no-playlist",
            // Parallelise DASH/HLS fragment downloads — large downloads are far
            // too slow when fetched one fragment at a time.
            "--concurrent-fragments", "8",
            "-o", destDir.path + "/" + template
        ]
        args += formatArgs(for: item.format, quality: item.quality)
        args.append(item.url)

        let code = await runYtDlp(ytdlp, args: args, item: item)

        // yt-dlp concluded early (e.g. "already downloaded").
        if case .done = item.status {
            if let temp { try? FileManager.default.removeItem(at: temp) }
            item.process = nil; processQueue(); return
        }
        guard code == 0 else {
            if case .failed = item.status {} else {
                item.status = .failed(item.errorLines.last
                    ?? "Download failed. Make sure the URL is valid and yt-dlp is up to date.")
            }
            if let temp { try? FileManager.default.removeItem(at: temp) }
            item.process = nil; processQueue(); return
        }

        if let temp {
            await mergeDownloads(item: item, tempDir: temp, into: folder)
            try? FileManager.default.removeItem(at: temp)
        } else {
            item.status = .done
            item.progress = 1.0
        }

        item.process = nil
        processQueue()
    }

    /// Runs yt-dlp, streaming progress into `item`, and returns the exit code.
    private func runYtDlp(_ exe: String, args: [String], item: DownloadItem) async -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exe)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        item.process = process

        pipe.fileHandleForReading.readabilityHandler = { [weak self, weak item] handle in
            guard let self, let item else { return }
            let data = handle.availableData
            guard !data.isEmpty, let str = String(data: data, encoding: .utf8) else { return }
            for line in str.components(separatedBy: "\n") {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { continue }
                Task { @MainActor in self.parse(t, item: item) }
            }
        }

        do { try process.run() }
        catch { item.status = .failed(error.localizedDescription); return -1 }

        await withCheckedContinuation { cont in
            DispatchQueue.global().async { process.waitUntilExit(); cont.resume() }
        }
        pipe.fileHandleForReading.readabilityHandler = nil
        return process.terminationStatus
    }

    /// Merges the downloaded video + audio streams in `tempDir` into a single
    /// mp4 in `folder` using AVFoundation (passthrough remux, no re-encode).
    private func mergeDownloads(item: DownloadItem, tempDir: URL, into folder: URL) async {
        let fm = FileManager.default
        let files = ((try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
        guard !files.isEmpty else { item.status = .failed("Download produced no file."); return }

        item.status = .converting
        item.progress = 0.95

        var videoFile: URL?
        var audioFile: URL?
        for f in files {
            let asset = AVURLAsset(url: f)
            let hasVideo = !(((try? await asset.loadTracks(withMediaType: .video)) ?? []).isEmpty)
            let hasAudio = !(((try? await asset.loadTracks(withMediaType: .audio)) ?? []).isEmpty)
            if hasVideo, videoFile == nil { videoFile = f }
            else if hasAudio, audioFile == nil { audioFile = f }
        }

        let source = videoFile ?? files[0]
        let title = source.deletingPathExtension().deletingPathExtension().lastPathComponent
        let output = uniqueURL(in: folder, name: title.isEmpty ? "video" : title, ext: "mp4")

        do {
            if let v = videoFile, let a = audioFile {
                try await merge(video: v, audio: a, to: output)
            } else {
                try fm.moveItem(at: source, to: output)
            }
            item.filePath = output.path
            item.title = output.deletingPathExtension().lastPathComponent
            item.status = .done
            item.progress = 1.0
        } catch {
            item.status = .failed("Merge failed: \(error.localizedDescription)")
        }
    }

    /// Combines a video-only and audio-only file into one mp4.
    private func merge(video: URL, audio: URL, to output: URL) async throws {
        let comp = AVMutableComposition()
        let vAsset = AVURLAsset(url: video)
        let aAsset = AVURLAsset(url: audio)

        guard let srcV = try await vAsset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "Reel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No video track found."])
        }
        let vDur = try await vAsset.load(.duration)
        let dstV = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try dstV?.insertTimeRange(CMTimeRange(start: .zero, duration: vDur), of: srcV, at: .zero)
        if let transform = try? await srcV.load(.preferredTransform) { dstV?.preferredTransform = transform }

        if let srcA = try await aAsset.loadTracks(withMediaType: .audio).first {
            let aDur = try await aAsset.load(.duration)
            let dstA = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try dstA?.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(aDur, vDur)), of: srcA, at: .zero)
        }

        do {
            try await export(comp, to: output, preset: AVAssetExportPresetPassthrough)
        } catch {
            // Codecs not mp4-passthrough compatible (e.g. VP9/Opus) — re-encode.
            try await export(comp, to: output, preset: AVAssetExportPresetHighestQuality)
        }
    }

    private func export(_ asset: AVAsset, to output: URL, preset: String) async throws {
        try? FileManager.default.removeItem(at: output)
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw NSError(domain: "Reel", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Export not supported for this media."])
        }
        session.outputURL = output
        session.outputFileType = .mp4
        await withCheckedContinuation { cont in
            session.exportAsynchronously { cont.resume() }
        }
        guard session.status == .completed else {
            throw session.error ?? NSError(domain: "Reel", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Export failed."])
        }
    }

    private func uniqueURL(in folder: URL, name: String, ext: String) -> URL {
        let fm = FileManager.default
        var candidate = folder.appendingPathComponent("\(name).\(ext)")
        var n = 1
        while fm.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(name) (\(n)).\(ext)")
            n += 1
        }
        return candidate
    }

    private func parse(_ line: String, item: DownloadItem) {
        // Destination
        if line.contains("[download] Destination:") {
            let f = line.components(separatedBy: "Destination: ").last?.trimmingCharacters(in: .whitespaces) ?? ""
            if !f.isEmpty {
                item.title = URL(fileURLWithPath: f).deletingPathExtension().lastPathComponent
                item.filePath = f
            }
        }
        // Merger destination
        if line.contains("[Merger] Merging formats into") {
            let f = line.components(separatedBy: "\"").dropFirst().first ?? ""
            if !f.isEmpty { item.filePath = f.trimmingCharacters(in: .whitespaces) }
            item.status = .converting; item.progress = 0.99
        }
        // Progress
        if line.hasPrefix("[download]"), line.contains("%"),
           !line.contains("has already been downloaded") {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for (i, p) in parts.enumerated() {
                if p.hasSuffix("%"), let v = Double(p.dropLast()) { item.progress = min(v/100, 1) }
                if p.hasSuffix("/s") { item.speed = p }
                if i > 0, parts[i-1] == "ETA" { item.eta = p == "Unknown" ? "" : p }
            }
            item.status = .downloading
        }
        // Already downloaded
        if line.contains("has already been downloaded") { item.status = .done; item.progress = 1 }
        // Collect error lines for better failure messages
        if line.hasPrefix("ERROR:") {
            item.errorLines.append(line.replacingOccurrences(of: "ERROR: ", with: ""))
        }
    }

    private func formatArgs(for format: DownloadFormat, quality: VideoQuality) -> [String] {
        // Resolution cap applied to video streams, e.g. "[height<=1080]". Empty = highest available.
        let cap = quality.maxHeight.map { "[height<=\($0)]" } ?? ""
        switch format {
        case .best, .mp4:
            // Best video-only + best audio as SEPARATE files (comma selector); the
            // app merges them locally with AVFoundation. mp4/m4a is preferred so the
            // merge is a fast passthrough remux.
            return ["-f", "bv*[ext=mp4]\(cap)/bv*\(cap),ba[ext=m4a]/ba"]
        case .mp3:
            // Grab the audio stream directly (m4a plays in Music.app)
            return ["-f", "bestaudio[ext=m4a]/bestaudio[ext=mp3]/bestaudio"]
        case .wav:
            return ["-f", "bestaudio[ext=m4a]/bestaudio"]
        }
    }

    private func findBin(_ name: String) -> String? {
        if let p = Bundle.main.path(forResource: name, ofType: nil) {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: p)
            return p
        }
        let paths = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }
}
