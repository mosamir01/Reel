import Foundation
import AppKit

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

    func add(url: String, format: DownloadFormat) {
        guard let folder = outputFolder else { needsFolderSetup = true; return }
        _ = folder   // silence unused warning
        let clean = url.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        let item = DownloadItem(url: clean, format: format)
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

        let ffmpeg = findBin("ffmpeg")
        var args: [String] = [
            "--newline", "--progress", "--no-playlist",
            "-o", folder.path + "/%(title)s.%(ext)s"
        ]
        if let ffmpeg { args += ["--ffmpeg-location", ffmpeg] }
        args += formatArgs(for: item.format, hasFFmpeg: ffmpeg != nil)
        args.append(item.url)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytdlp)
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
        catch { item.status = .failed(error.localizedDescription); processQueue(); return }

        await withCheckedContinuation { cont in
            DispatchQueue.global().async { process.waitUntilExit(); cont.resume() }
        }

        pipe.fileHandleForReading.readabilityHandler = nil

        switch item.status {
        case .done, .failed: break
        default:
            if process.terminationStatus == 0 {
                item.status = .done
                item.progress = 1.0
            } else {
                let msg = item.errorLines.last
                    ?? "Download failed. Make sure the URL is valid and yt-dlp is up to date."
                item.status = .failed(msg)
            }
        }

        item.process = nil
        processQueue()
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
        // ffmpeg post-process
        if line.hasPrefix("[ffmpeg]") { item.status = .converting; item.progress = 0.99 }
        // Collect error lines for better failure messages
        if line.hasPrefix("ERROR:") || line.contains("not find ffmpeg") || line.contains("ffmpeg not found") {
            item.errorLines.append(line.replacingOccurrences(of: "ERROR: ", with: ""))
        }
    }

    private func formatArgs(for format: DownloadFormat, hasFFmpeg: Bool) -> [String] {
        switch format {
        case .best:
            // With ffmpeg: merge best video + best audio into mp4
            // Without ffmpeg: download best single-file format (avoids separate streams)
            if hasFFmpeg {
                return ["-f", "bestvideo+bestaudio/best", "--merge-output-format", "mp4"]
            } else {
                return ["-f", "best[ext=mp4]/best[vcodec!=none][acodec!=none]/best"]
            }
        case .mp4:
            if hasFFmpeg {
                return ["-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best", "--merge-output-format", "mp4"]
            } else {
                return ["-f", "best[ext=mp4]/best[vcodec!=none][acodec!=none]/best"]
            }
        case .mp3:
            // MP3 conversion requires ffmpeg; without it, download best audio as-is (m4a/opus)
            if hasFFmpeg {
                return ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
            } else {
                return ["-f", "bestaudio[ext=m4a]/bestaudio", "-x"]
            }
        case .wav:
            if hasFFmpeg {
                return ["-x", "--audio-format", "wav"]
            } else {
                return ["-f", "bestaudio[ext=m4a]/bestaudio", "-x"]
            }
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
