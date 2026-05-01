import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var dm: DownloadManager
    @State private var urlText = ""
    @State private var format: DownloadFormat = .best

    var body: some View {
        VStack(spacing: 0) {
            // Input bar
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "link").foregroundColor(.secondary)
                    TextField("Paste a URL from YouTube, TikTok, Instagram, Twitter, Reddit…", text: $urlText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit { addDownload() }
                    if !urlText.isEmpty {
                        Button { urlText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3), lineWidth: 1))

                HStack(spacing: 8) {
                    Text("Format:").font(.caption).foregroundColor(.secondary)
                    ForEach(DownloadFormat.allCases) { f in
                        Button(f.rawValue) { format = f }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .background(format == f ? Color.accentColor.opacity(0.12) : Color.clear)
                            .cornerRadius(5)
                    }
                    Spacer()
                    Button {
                        let url = urlText.trimmingCharacters(in: .whitespaces)
                        guard !url.isEmpty else { return }
                        addDownload()
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            if dm.items.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(dm.items) { item in
                            DownloadRow(item: item)
                                .environmentObject(dm)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .toolbar {
            ToolbarItemGroup {
                if let folder = dm.outputFolder {
                    Button {
                        dm.openOutputFolder()
                    } label: {
                        Label(folderName(folder), systemImage: "folder")
                    }
                    .help("Open downloads folder")
                }
                Button { dm.pickOutputFolder() } label: {
                    Image(systemName: "folder.badge.plus")
                }.help("Change download folder")
                if dm.items.contains(where: { switch $0.status { case .done,.failed: return true; default: return false } }) {
                    Button { dm.clearCompleted() } label: {
                        Image(systemName: "trash")
                    }.help("Clear completed")
                }
            }
        }
        .sheet(isPresented: $dm.needsFolderSetup) {
            FolderSetupView()
                .environmentObject(dm)
        }
    }

    func addDownload() {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        dm.add(url: url, format: format)
        urlText = ""
    }

    func folderName(_ url: URL) -> String {
        url.lastPathComponent
    }
}

// MARK: - Folder Setup (first launch)

struct FolderSetupView: View {
    @EnvironmentObject var dm: DownloadManager

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 52))
                .foregroundColor(.accentColor)

            Text("Where should Reel save downloads?")
                .font(.title2).fontWeight(.semibold)

            Text("Choose a folder on your Mac. You can change this anytime from the toolbar.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                dm.pickOutputFolder()
            } label: {
                Label("Choose Folder", systemImage: "folder.badge.plus")
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Use Downloads Folder") {
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
                dm.pickOutputFolder() // will open panel; user can navigate to Downloads
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)
        }
        .padding(40)
        .frame(width: 440, height: 320)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let sites = ["YouTube", "TikTok", "Instagram", "Twitter/X", "Reddit", "Vimeo", "SoundCloud", "Twitch", "+1000 more"]

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary)

            Text("Paste any video or audio URL")
                .font(.title3).fontWeight(.medium)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 6) {
                ForEach(sites, id: \.self) { site in
                    Text(site)
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(.secondary)
    }
}

// MARK: - Download Row

struct DownloadRow: View {
    @ObservedObject var item: DownloadItem
    @EnvironmentObject var dm: DownloadManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                statusIcon
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.format.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .cornerRadius(3)
                        Text(statusLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                actionButtons
            }

            // Progress bar
            if case .downloading = item.status {
                VStack(spacing: 3) {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("\(Int(item.progress * 100))%")
                        if !item.speed.isEmpty { Text("·").opacity(0.4); Text(item.speed) }
                        if !item.eta.isEmpty { Text("· ETA \(item.eta)") }
                        Spacer()
                    }
                    .font(.caption).foregroundColor(.secondary)
                }
            } else if case .converting = item.status {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Converting…").font(.caption).foregroundColor(.secondary)
                }
            } else if case .failed(let msg) = item.status {
                Text(msg).font(.caption).foregroundColor(.red).lineLimit(3)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    var statusIcon: some View {
        Group {
            switch item.status {
            case .queued:      Image(systemName: "clock").foregroundColor(.secondary)
            case .fetching:    ProgressView().scaleEffect(0.65)
            case .downloading: Image(systemName: "arrow.down.circle").foregroundColor(.blue)
            case .converting:  Image(systemName: "gearshape").foregroundColor(.orange)
            case .done:        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
            case .failed:      Image(systemName: "xmark.circle.fill").foregroundColor(.red)
            }
        }
    }

    var statusLabel: String {
        switch item.status {
        case .queued:      return "Queued"
        case .fetching:    return "Getting info…"
        case .downloading: return "Downloading"
        case .converting:  return "Converting"
        case .done:        return "Done"
        case .failed:      return "Failed"
        }
    }

    var actionButtons: some View {
        HStack(spacing: 6) {
            switch item.status {
            case .done:
                Button("Open") { dm.openFile(item) }
                    .buttonStyle(.bordered).controlSize(.small)
                Button { dm.remove(item) } label: {
                    Image(systemName: "xmark").font(.caption)
                }.buttonStyle(.plain).foregroundColor(.secondary)
            case .failed:
                Button("Retry") {
                    item.status = .queued
                    dm.add(url: item.url, format: item.format)
                    dm.remove(item)
                }.buttonStyle(.bordered).controlSize(.small)
                Button { dm.remove(item) } label: {
                    Image(systemName: "xmark").font(.caption)
                }.buttonStyle(.plain).foregroundColor(.secondary)
            default:
                Button("Cancel") { dm.cancel(item) }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}
