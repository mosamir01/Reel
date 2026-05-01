import SwiftUI
import AppKit

// MARK: - Sidebar sections

enum SidebarSection: String, CaseIterable, Identifiable {
    case all        = "All"
    case active     = "Downloading"
    case queued     = "Queued"
    case completed  = "Completed"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:       return "list.bullet"
        case .active:    return "arrow.down.circle"
        case .queued:    return "clock"
        case .completed: return "checkmark.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .all:       return .secondary
        case .active:    return .blue
        case .queued:    return .orange
        case .completed: return .green
        }
    }
}

// MARK: - Root view

struct ContentView: View {
    @EnvironmentObject var dm: DownloadManager
    @State private var urlText = ""
    @State private var format: DownloadFormat = .best
    @State private var selectedSection: SidebarSection = .all

    var filteredItems: [DownloadItem] {
        switch selectedSection {
        case .all:       return dm.items
        case .active:    return dm.items.filter { $0.status.isActive }
        case .queued:    return dm.items.filter { if case .queued = $0.status { return true }; return false }
        case .completed: return dm.items.filter {
            switch $0.status { case .done, .failed: return true; default: return false }
        }
        }
    }

    func count(for section: SidebarSection) -> Int {
        switch section {
        case .all:       return dm.items.count
        case .active:    return dm.items.filter { $0.status.isActive }.count
        case .queued:    return dm.items.filter { if case .queued = $0.status { return true }; return false }.count
        case .completed: return dm.items.filter {
            switch $0.status { case .done, .failed: return true; default: return false }
        }.count
        }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedSection: $selectedSection, count: count)
                .environmentObject(dm)
        } detail: {
            DetailView(
                urlText: $urlText,
                format: $format,
                selectedSection: selectedSection,
                filteredItems: filteredItems,
                addDownload: addDownload
            )
            .environmentObject(dm)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 700, minHeight: 460)
        .sheet(isPresented: $dm.needsFolderSetup) {
            FolderSetupView().environmentObject(dm)
        }
    }

    func addDownload() {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        dm.add(url: url, format: format)
        urlText = ""
    }
}

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var dm: DownloadManager
    @Binding var selectedSection: SidebarSection
    let count: (SidebarSection) -> Int

    var body: some View {
        List(SidebarSection.allCases, selection: $selectedSection) { section in
            Label {
                HStack {
                    Text(section.rawValue)
                    Spacer()
                    let c = count(section)
                    if c > 0 {
                        Text("\(c)")
                            .font(.caption2).fontWeight(.semibold)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(section == selectedSection
                                ? Color.white.opacity(0.25)
                                : Color.secondary.opacity(0.15))
                            .foregroundColor(section == selectedSection ? .white : .secondary)
                            .cornerRadius(8)
                    }
                }
            } icon: {
                Image(systemName: section.icon)
                    .foregroundColor(section.iconColor)
            }
            .tag(section)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
        .safeAreaInset(edge: .bottom) {
            SidebarFooter().environmentObject(dm)
        }
    }
}

struct SidebarFooter: View {
    @EnvironmentObject var dm: DownloadManager

    var body: some View {
        VStack(spacing: 6) {
            Divider()
            HStack(spacing: 8) {
                if let folder = dm.outputFolder {
                    Button {
                        dm.openOutputFolder()
                    } label: {
                        Label(folder.lastPathComponent, systemImage: "folder")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Open: \(folder.path)")
                }
                Spacer()
                Button {
                    dm.pickOutputFolder()
                } label: {
                    Image(systemName: "folder.badge.plus").font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Change folder")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Detail area

struct DetailView: View {
    @EnvironmentObject var dm: DownloadManager
    @Binding var urlText: String
    @Binding var format: DownloadFormat
    let selectedSection: SidebarSection
    let filteredItems: [DownloadItem]
    let addDownload: () -> Void

    var hasCompleted: Bool {
        dm.items.contains { switch $0.status { case .done, .failed: return true; default: return false } }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top input bar
            InputBar(urlText: $urlText, format: $format, addDownload: addDownload)

            Divider()

            // Content
            if filteredItems.isEmpty {
                if dm.items.isEmpty {
                    EmptyStateView()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundColor(.secondary)
                        Text("Nothing in \(selectedSection.rawValue)")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredItems) { item in
                            DownloadRow(item: item).environmentObject(dm)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .toolbar {
            ToolbarItem {
                if hasCompleted {
                    Button {
                        dm.clearCompleted()
                    } label: {
                        Label("Clear Completed", systemImage: "trash")
                    }
                    .help("Remove done and failed items")
                }
            }
        }
    }
}

// MARK: - Input bar

struct InputBar: View {
    @Binding var urlText: String
    @Binding var format: DownloadFormat
    let addDownload: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "link").foregroundColor(.secondary)
                TextField("Paste a URL — YouTube, TikTok, Instagram, Twitter, Reddit…", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { addDownload() }
                if !urlText.isEmpty {
                    Button { urlText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25), lineWidth: 1))

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

            Text("Choose a folder on your Mac. You can change this anytime from the sidebar.")
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
        }
        .padding(40)
        .frame(width: 440, height: 280)
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
                statusIcon.frame(width: 18)
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

            if case .downloading = item.status {
                VStack(spacing: 3) {
                    ProgressView(value: item.progress).progressViewStyle(.linear)
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
                    let url = item.url; let fmt = item.format
                    dm.remove(item)
                    dm.add(url: url, format: fmt)
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
