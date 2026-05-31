import SwiftUI
import AppKit

// MARK: - Design tokens
extension Color {
    // Surfaces & text adapt to the active appearance (light / dark).
    static let rBg       = Color(light: 0xFFFFFF, dark: 0x0A0A0A)
    static let rSidebar  = Color(light: 0xF5F5F7, dark: 0x0B0B0B)
    static let rToolbar  = Color(light: 0xF5F5F7, dark: 0x0B0B0B)
    static let rSurface  = Color(light: 0xEFEFF1, dark: 0x141414)
    static let rSurface2 = Color(light: 0xE7E7EA, dark: 0x1A1A1A)
    static let rBorder   = Color.ink(0.10)
    static let rBorder2  = Color.ink(0.05)
    static let rFg       = Color(light: 0x111111, dark: 0xF0F0F0)
    static let rFg2      = Color(light: 0x5A5A5F, dark: 0xA3A3A3)
    static let rFg3      = Color(light: 0x9A9AA0, dark: 0x555555)
    static let rGreen    = Color(light: 0x1FA971, dark: 0x3ECF8E)
    static let rAmber    = Color(light: 0xD2860A, dark: 0xF5A623)
    static let rRed      = Color(light: 0xE23B3B, dark: 0xFF4D4D)
    static let rBlue     = Color(light: 0x2563EB, dark: 0x60A5FA)

    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }

    /// A color that resolves to a different hex per appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 0xFF) / 255,
                           green:   Double((hex >>  8) & 0xFF) / 255,
                           blue:    Double( hex        & 0xFF) / 255,
                           alpha:   1)
        })
    }

    /// Foreground "ink" — white in dark mode, black in light mode — at the given opacity.
    static func ink(_ opacity: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(white: isDark ? 1 : 0, alpha: opacity)
        })
    }
}

// MARK: - Platform badge
struct PlatformBadge: View {
    let url: String

    var info: (label: String, bg: Color, fg: Color) {
        let u = url.lowercased()
        if u.contains("youtube") || u.contains("youtu.be") {
            return ("YT", Color.red.opacity(0.14), Color(hex: 0xFF4444))
        }
        if u.contains("instagram") {
            return ("IG", Color.purple.opacity(0.12), Color(hex: 0xC855F7))
        }
        if u.contains("tiktok") {
            return ("TT", Color.ink(0.07), Color(hex: 0xD4D4D4))
        }
        if u.contains("soundcloud") {
            return ("SC", Color.orange.opacity(0.12), Color(hex: 0xFF5500))
        }
        if u.contains("twitter") || u.contains("x.com") {
            return ("X", Color.ink(0.07), Color(hex: 0xA3A3A3))
        }
        if u.contains("reddit") {
            return ("R", Color.orange.opacity(0.12), Color(hex: 0xFF4500))
        }
        if u.contains("vimeo") {
            return ("VI", Color.blue.opacity(0.12), Color(hex: 0x60A5FA))
        }
        if u.contains("twitch") {
            return ("TW", Color.purple.opacity(0.12), Color(hex: 0x9F7AEA))
        }
        return ("↓", Color.ink(0.06), Color(hex: 0x555555))
    }

    var body: some View {
        Text(info.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(info.fg)
            .frame(width: 28, height: 28)
            .background(info.bg)
            .cornerRadius(6)
    }
}

// MARK: - Sidebar sections
enum SidebarSection: String, CaseIterable, Identifiable {
    case all       = "All"
    case active    = "Downloading"
    case queued    = "Queued"
    case completed = "Completed"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all:       return "tray"
        case .active:    return "arrow.down.to.line"
        case .queued:    return "hourglass"
        case .completed: return "checkmark"
        }
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @EnvironmentObject var dm: DownloadManager
    @Binding var selectedSection: SidebarSection
    let count: (SidebarSection) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Nav section
            VStack(alignment: .leading, spacing: 2) {
                Text("LIBRARY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.ink(0.18))
                    .tracking(1.2)
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 10)

                ForEach(SidebarSection.allCases) { section in
                    SidebarNavItem(
                        section: section,
                        isSelected: selectedSection == section,
                        count: count(section)
                    )
                    .onTapGesture { selectedSection = section }
                }
            }

            Spacer()
            Divider().background(Color.rBorder2)
            SidebarFooter().environmentObject(dm)
        }
        .frame(minWidth: 180, idealWidth: 200, maxWidth: 210)
        .background(Color.rSidebar)
    }
}

struct SidebarNavItem: View {
    let section: SidebarSection
    let isSelected: Bool
    let count: Int

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 9) {
                Image(systemName: section.icon)
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? Color.ink(0.85) : Color.ink(0.5))
                    .frame(width: 20)
                Text(section.rawValue)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(isSelected ? Color.ink(0.88) : Color.ink(0.38))
                    .kerning(-0.2)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(isSelected ? Color.ink(0.55) : Color.ink(0.28))
                        .padding(.horizontal, 5.5).padding(.vertical, 1.5)
                        .background(isSelected ? Color.ink(0.09) : Color.ink(0.05))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? Color.ink(0.065) : Color.clear)
            .cornerRadius(6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())

            if isSelected {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.rGreen.opacity(0.7))
                    .frame(width: 2, height: 14)
            }
        }
    }
}

struct SidebarFooter: View {
    @EnvironmentObject var dm: DownloadManager
    @AppStorage("reelLightMode") private var lightMode = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundColor(.rFg3)
            Text(dm.outputFolder?.lastPathComponent ?? "No folder")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.rFg2)
                .lineLimit(1)
            Spacer()
            Button { lightMode.toggle() } label: {
                Image(systemName: lightMode ? "moon.fill" : "sun.max.fill").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.rFg3)
            .help(lightMode ? "Switch to dark mode" : "Switch to light mode")
            Button { dm.pickOutputFolder() } label: {
                Image(systemName: "gearshape").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundColor(.rFg3)
            .help("Change folder")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.rSidebar)
    }
}

// MARK: - Input bar
struct InputBar: View {
    @EnvironmentObject var dm: DownloadManager
    @Binding var urlText: String
    @Binding var format: DownloadFormat
    @Binding var quality: VideoQuality
    let addDownload: () -> Void

    private var hasClearable: Bool {
        dm.items.contains { switch $0.status { case .done, .failed: return true; default: return false } }
    }

    var body: some View {
        VStack(spacing: 10) {
            // URL field
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 13))
                    .foregroundColor(.rFg3)
                TextField("Paste a URL — YouTube, TikTok, Instagram, Twitter, Reddit…", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.rFg)
                    .onSubmit { addDownload() }
                if !urlText.isEmpty {
                    Button { urlText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.rFg3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.ink(0.04))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.ink(0.06)))
            .cornerRadius(8)

            // Format picker + Download button
            HStack(spacing: 6) {
                HStack(spacing: 0) {
                    ForEach(Array(DownloadFormat.allCases.enumerated()), id: \.offset) { idx, f in
                        Button(f.rawValue.uppercased()) { format = f }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(format == f ? .rFg : .rFg3)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(format == f ? Color.ink(0.10) : Color.clear)
                            .buttonStyle(.plain)
                        if idx < DownloadFormat.allCases.count - 1 {
                            Rectangle()
                                .fill(Color.rBorder)
                                .frame(width: 1, height: 16)
                        }
                    }
                }
                .background(Color.rSurface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.rBorder))
                .cornerRadius(6)

                // Resolution picker — only relevant for video formats
                if format.isVideo {
                    Menu {
                        ForEach(VideoQuality.allCases) { q in
                            Button {
                                quality = q
                            } label: {
                                if quality == q {
                                    Label(q.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(q.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 10))
                            Text(quality.rawValue).font(.system(size: 11, weight: .semibold))
                            Image(systemName: "chevron.down").font(.system(size: 7, weight: .bold))
                        }
                        .foregroundColor(.rFg2)
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(Color.rSurface)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.rBorder))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }

                Spacer()

                if hasClearable {
                    Button { dm.clearCompleted() } label: {
                        Text("Clear Completed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.rFg3)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.rSurface)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.rBorder))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Remove done and failed items")
                }

                let canDownload = !urlText.trimmingCharacters(in: .whitespaces).isEmpty
                Button(action: addDownload) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 12))
                        Text("Download").font(.system(size: 11.5, weight: .bold)).kerning(-0.2)
                    }
                    .foregroundColor(Color.rBg)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(canDownload ? Color.rFg : Color.rFg3)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(!canDownload)
            }
        }
        .padding(14)
        .background(Color.rToolbar)
    }
}

// MARK: - Download row button style
struct DarkActionButtonStyle: ButtonStyle {
    let isPrimary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isPrimary ? .rGreen : .rFg3)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(isPrimary ? Color.rGreen.opacity(0.10) : Color.ink(0.05))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(isPrimary ? Color.rGreen.opacity(0.30) : Color.rBorder))
            .cornerRadius(5)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Download row
struct DownloadRow: View {
    @ObservedObject var item: DownloadItem
    @EnvironmentObject var dm: DownloadManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                PlatformBadge(url: item.url)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.ink(0.82))
                        .lineLimit(1)
                        .kerning(-0.2)
                    HStack(spacing: 6) {
                        formatTag
                        if item.format.isVideo && item.quality != .best {
                            Text(item.quality.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.4)
                                .foregroundColor(.rFg3)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.ink(0.05))
                                .cornerRadius(3)
                        }
                        Text(statusLabel)
                            .font(.system(size: 11))
                            .foregroundColor(.rFg3)
                    }
                }

                Spacer()
                actionButtons
            }

            // Progress
            if case .downloading = item.status {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 99)
                                .fill(Color.ink(0.05))
                                .frame(height: 1.5)
                            RoundedRectangle(cornerRadius: 99)
                                .fill(Color.rBlue)
                                .frame(width: geo.size.width * item.progress, height: 1.5)
                        }
                    }
                    .frame(height: 1.5)

                    HStack(spacing: 6) {
                        Text("\(Int(item.progress * 100))%")
                        if !item.speed.isEmpty {
                            Text("·").opacity(0.3)
                            Text(item.speed)
                        }
                        if !item.eta.isEmpty {
                            Text("·").opacity(0.3)
                            Text("ETA \(item.eta)")
                        }
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.rFg3)
                }
                .padding(.leading, 40)

            } else if case .converting = item.status {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.55).tint(.rFg3)
                    Text("Converting…").font(.system(size: 11)).foregroundColor(.rFg3)
                }
                .padding(.leading, 40)

            } else if case .failed(let msg) = item.status {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.rRed.opacity(0.85))
                    .lineLimit(2)
                    .padding(.leading, 40)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(Color.rBg)
        .overlay(
            Rectangle()
                .fill(Color.ink(0.03))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    var formatTag: some View {
        let (bg, fg): (Color, Color) = {
            switch item.status {
            case .downloading: return (Color.rBlue.opacity(0.12), .rBlue)
            case .done:        return (Color.rGreen.opacity(0.12), .rGreen)
            case .failed:      return (Color.rRed.opacity(0.12),   .rRed)
            case .queued:      return (Color.rAmber.opacity(0.12), .rAmber)
            default:           return (Color.ink(0.07),  .rFg3)
            }
        }()
        return Text(item.format.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.4)
            .foregroundColor(fg)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(bg)
            .cornerRadius(3)
    }

    var statusLabel: String {
        switch item.status {
        case .queued:              return "Queued"
        case .fetching:            return "Getting info…"
        case .downloading:         return "Downloading · \(Int(item.progress * 100))%"
        case .converting:          return "Converting"
        case .done:                return "Done"
        case .failed:              return "Failed"
        }
    }

    var actionButtons: some View {
        HStack(spacing: 6) {
            switch item.status {
            case .done:
                Button("Open") { dm.openFile(item) }
                    .buttonStyle(DarkActionButtonStyle(isPrimary: true))
                Button { dm.remove(item) } label: {
                    Image(systemName: "xmark").font(.system(size: 10))
                }
                .buttonStyle(DarkActionButtonStyle(isPrimary: false))

            case .failed:
                Button("Retry") {
                    let u = item.url; let f = item.format; let q = item.quality
                    dm.remove(item)
                    dm.add(url: u, format: f, quality: q)
                }
                .buttonStyle(DarkActionButtonStyle(isPrimary: false))
                Button { dm.remove(item) } label: {
                    Image(systemName: "xmark").font(.system(size: 10))
                }
                .buttonStyle(DarkActionButtonStyle(isPrimary: false))

            default:
                Button("Cancel") { dm.cancel(item) }
                    .buttonStyle(DarkActionButtonStyle(isPrimary: false))
            }
        }
    }
}

// MARK: - Empty state
struct EmptyStateView: View {
    let sites = ["YouTube", "TikTok", "Instagram", "Twitter / X", "Reddit", "Vimeo", "SoundCloud", "Twitch", "+1000 more"]

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.rSurface)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rBorder))
                    .frame(width: 64, height: 64)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 26, weight: .thin))
                    .foregroundColor(.rFg3)
            }

            VStack(spacing: 6) {
                Text("Paste any video or audio URL")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.rFg)
                Text("Copy a link from your browser and paste it above.\nReel handles the rest.")
                    .font(.system(size: 13))
                    .foregroundColor(.rFg3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 6) {
                ForEach(sites, id: \.self) { s in
                    Text(s)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.rFg3)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.rSurface)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.rBorder))
                        .cornerRadius(5)
                }
            }
            .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.rBg)
    }
}

// MARK: - Status bar
struct StatusBar: View {
    @EnvironmentObject var dm: DownloadManager

    var activeCount: Int    { dm.items.filter { $0.status.isActive }.count }
    var completedCount: Int { dm.items.filter { if case .done = $0.status { return true }; return false }.count }

    var body: some View {
        HStack(spacing: 14) {
            if activeCount > 0 {
                HStack(spacing: 4) {
                    Circle().fill(Color.rAmber).frame(width: 5, height: 5)
                    Text("\(activeCount) active")
                        .font(.system(size: 9.5))
                        .foregroundColor(Color.ink(0.28))
                        .kerning(-0.1)
                }
            }
            if completedCount > 0 {
                HStack(spacing: 4) {
                    Circle().fill(Color.rGreen).frame(width: 5, height: 5)
                    Text("\(completedCount) completed")
                        .font(.system(size: 9.5))
                        .foregroundColor(Color.ink(0.28))
                        .kerning(-0.1)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 5)
        .background(Color.rToolbar)
        .overlay(
            Rectangle().fill(Color.ink(0.03)).frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Detail view
struct DetailView: View {
    @EnvironmentObject var dm: DownloadManager
    @Binding var urlText: String
    @Binding var format: DownloadFormat
    @Binding var quality: VideoQuality
    let selectedSection: SidebarSection
    let filteredItems: [DownloadItem]
    let addDownload: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            InputBar(urlText: $urlText, format: $format, quality: $quality, addDownload: addDownload)

            Rectangle().fill(Color.rBorder2).frame(height: 1)

            if filteredItems.isEmpty {
                if dm.items.isEmpty {
                    EmptyStateView()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 32, weight: .thin))
                            .foregroundColor(.rFg3)
                        Text("Nothing in \(selectedSection.rawValue)")
                            .font(.system(size: 13))
                            .foregroundColor(.rFg3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.rBg)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            DownloadRow(item: item).environmentObject(dm)
                        }
                    }
                }
                .background(Color.rBg)
            }

            StatusBar().environmentObject(dm)
        }
    }
}

// MARK: - Folder setup sheet
struct FolderSetupView: View {
    @EnvironmentObject var dm: DownloadManager
    @AppStorage("reelLightMode") private var lightMode = false

    var body: some View {
        ZStack {
            Color.rBg.ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.rSurface2)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.rBorder))
                        .frame(width: 72, height: 72)
                    Text("📁").font(.system(size: 32))
                }

                VStack(spacing: 8) {
                    Text("Where should Reel save downloads?")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.rFg)
                        .multilineTextAlignment(.center)
                    Text("Choose a folder on your Mac. You can change this anytime from the sidebar.")
                        .font(.system(size: 13))
                        .foregroundColor(.rFg3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                        .lineSpacing(3)
                }

                Button { dm.pickOutputFolder() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text("Choose Folder")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.rBg)
                    .frame(width: 220)
                    .padding(.vertical, 12)
                    .background(Color.rFg)
                    .cornerRadius(9)
                }
                .buttonStyle(.plain)
            }
            .padding(40)
        }
        .frame(width: 440, height: 300)
        .preferredColorScheme(lightMode ? .light : .dark)
    }
}

// MARK: - Window chrome
/// Makes the title bar transparent and hides its title so the window's own dark
/// background fills the top edge — removing the light system title-bar strip.
struct WindowConfigurator: NSViewRepresentable {
    var dark: Bool
    var dm: DownloadManager
    final class HostView: NSView {
        var onWindow: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let w = window { onWindow?(w) }
        }
    }
    func makeNSView(context: Context) -> NSView {
        let v = HostView()
        v.onWindow = { apply(to: $0) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        if let w = nsView.window { apply(to: w) }
    }
    private func apply(to window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        let hex: UInt32 = dark ? 0x0B0B0B : 0xF5F5F7
        window.backgroundColor = NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green:   CGFloat((hex >>  8) & 0xFF) / 255,
            blue:    CGFloat( hex        & 0xFF) / 255,
            alpha: 1)
        installPasteAccessory(window)
    }
    /// Adds the "Paste link" button as a custom titlebar accessory so it renders
    /// in our theme with no Liquid Glass capsule (unlike a toolbar item).
    private func installPasteAccessory(_ window: NSWindow) {
        let id = NSUserInterfaceItemIdentifier("reelPasteLink")
        if window.titlebarAccessoryViewControllers.contains(where: { $0.identifier == id }) { return }
        let acc = NSTitlebarAccessoryViewController()
        acc.identifier = id
        acc.layoutAttribute = .trailing
        let host = NSHostingView(rootView: PasteLinkBar().environmentObject(dm))
        host.frame = NSRect(x: 0, y: 0, width: 130, height: 30)
        acc.view = host
        window.addTitlebarAccessoryViewController(acc)
    }
}

/// Themed "Paste link" button shown in the title bar. Reads a URL from the
/// clipboard and queues it instantly.
struct PasteLinkBar: View {
    @EnvironmentObject var dm: DownloadManager
    @State private var added = false

    var body: some View {
        Button {
            let s = (NSPasteboard.general.string(forType: .string) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard s.lowercased().hasPrefix("http") else { return }
            dm.add(url: s, format: .best, quality: .best)
            added = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { added = false }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: added ? "checkmark" : "doc.on.clipboard")
                    .font(.system(size: 10, weight: .bold))
                Text(added ? "Added" : "Paste link")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundColor(added ? .rGreen : .rFg2)
            .padding(.horizontal, 11).padding(.vertical, 4)
            .background(Color.rSurface)
            .overlay(Capsule().stroke(Color.rBorder, lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 12)
        .help("Download a link from your clipboard")
    }
}

// MARK: - Root view
struct ContentView: View {
    @EnvironmentObject var dm: DownloadManager
    @AppStorage("reelLightMode") private var lightMode = false
    @State private var urlText = ""
    @State private var format: DownloadFormat = .best
    @State private var quality: VideoQuality = .best
    @State private var selectedSection: SidebarSection = .all

    var filteredItems: [DownloadItem] {
        switch selectedSection {
        case .all:
            return dm.items
        case .active:
            return dm.items.filter { $0.status.isActive }
        case .queued:
            return dm.items.filter {
                if case .queued = $0.status { return true }
                return false
            }
        case .completed:
            return dm.items.filter {
                switch $0.status { case .done, .failed: return true; default: return false }
            }
        }
    }

    func count(for section: SidebarSection) -> Int {
        switch section {
        case .all:
            return dm.items.count
        case .active:
            return dm.items.filter { $0.status.isActive }.count
        case .queued:
            return dm.items.filter {
                if case .queued = $0.status { return true }
                return false
            }.count
        case .completed:
            return dm.items.filter {
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
                quality: $quality,
                selectedSection: selectedSection,
                filteredItems: filteredItems,
                addDownload: addDownload
            )
            .environmentObject(dm)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 720, minHeight: 480)
        .background(Color.rBg)
        .background(WindowConfigurator(dark: !lightMode, dm: dm))
        .preferredColorScheme(lightMode ? .light : .dark)
        .task(id: lightMode) {
            // Drive the AppKit appearance directly so the custom NSColor-backed
            // tokens re-resolve immediately when the theme is toggled.
            NSApp.appearance = NSAppearance(named: lightMode ? .aqua : .darkAqua)
        }
        .sheet(isPresented: $dm.needsFolderSetup) {
            FolderSetupView().environmentObject(dm)
        }
    }

    func addDownload() {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        dm.add(url: url, format: format, quality: quality)
        urlText = ""
    }
}
