# Pure Dark Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign Reel's entire UI to match the Pure Dark demo — new color system, redesigned sidebar with platform chips and storage footer, segmented format control, platform badges on rows, thin progress bars with monospaced stats, empty state, folder setup sheet, status bar, and matching app icon.

**Architecture:** Full rewrite of `ContentView.swift` with a new color palette defined as `Color` extensions. `DownloadManager.swift` and `DownloadItem.swift` are unchanged. App icon regenerated via Python/Pillow.

**Tech Stack:** SwiftUI (macOS), Python + Pillow (icon generation)

---

### Task 1: Color System & Platform Badge

**Files:**
- Modify: `Reel/ContentView.swift` (replace entire file)

- [ ] **Step 1: Define color extensions at top of ContentView.swift**

Replace the entire file with a fresh start containing only the color system and the `PlatformBadge` view:

```swift
import SwiftUI
import AppKit

// MARK: - Design tokens
extension Color {
    static let rBg        = Color(hex: 0x0A0A0A)
    static let rSidebar   = Color(hex: 0x0E0E0E)
    static let rToolbar   = Color(hex: 0x0C0C0C)
    static let rSurface   = Color(hex: 0x141414)
    static let rSurface2  = Color(hex: 0x1A1A1A)
    static let rBorder    = Color.white.opacity(0.07)
    static let rBorder2   = Color.white.opacity(0.04)
    static let rFg        = Color(hex: 0xF0F0F0)
    static let rFg2       = Color(hex: 0xA3A3A3)
    static let rFg3       = Color(hex: 0x555555)
    static let rGreen     = Color(hex: 0x3ECF8E)
    static let rAmber     = Color(hex: 0xF5A623)
    static let rRed       = Color(hex: 0xFF4D4D)
    static let rBlue      = Color(hex: 0x60A5FA)
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }
}

// MARK: - Platform badge
struct PlatformBadge: View {
    let url: String
    var info: (label: String, bg: Color, fg: Color) {
        let u = url.lowercased()
        if u.contains("youtube") || u.contains("youtu.be") { return ("YT", Color.red.opacity(0.12),   Color(hex: 0xFF4444)) }
        if u.contains("instagram")                          { return ("IG", Color.purple.opacity(0.1), Color(hex: 0xC855F7)) }
        if u.contains("tiktok")                             { return ("TT", Color.white.opacity(0.07), Color(hex: 0xF0F0F0)) }
        if u.contains("soundcloud")                         { return ("SC", Color.orange.opacity(0.1), Color(hex: 0xFF5500)) }
        if u.contains("twitter") || u.contains("x.com")    { return ("X",  Color.white.opacity(0.07), Color(hex: 0xA3A3A3)) }
        if u.contains("reddit")                             { return ("R",  Color.orange.opacity(0.1), Color(hex: 0xFF4500)) }
        if u.contains("vimeo")                              { return ("VI", Color.blue.opacity(0.1),   Color(hex: 0x60A5FA)) }
        if u.contains("twitch")                             { return ("TW", Color.purple.opacity(0.1), Color(hex: 0x9F7AEA)) }
        return ("↓", Color.white.opacity(0.06), Color(hex: 0x555555))
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
```

---

### Task 2: Sidebar Views

**Files:**
- Modify: `Reel/ContentView.swift` (append sections)

- [ ] **Step 1: Add SidebarSection enum and SidebarView**

Append after PlatformBadge:

```swift
// MARK: - Sidebar sections
enum SidebarSection: String, CaseIterable, Identifiable {
    case all = "All", active = "Downloading", queued = "Queued", completed = "Completed"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"; case .active: return "arrow.down.circle"
        case .queued: return "clock"; case .completed: return "checkmark.circle"
        }
    }
    var statusColor: Color {
        switch self {
        case .all: return .rFg3; case .active: return .rBlue
        case .queued: return .rAmber; case .completed: return .rGreen
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var dm: DownloadManager
    @Binding var selectedSection: SidebarSection
    let count: (SidebarSection) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Nav items
            VStack(alignment: .leading, spacing: 2) {
                Text("LIBRARY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.rFg3)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 6)
                    .tracking(1.0)
                ForEach(SidebarSection.allCases) { section in
                    SidebarNavItem(
                        section: section,
                        isSelected: selectedSection == section,
                        count: count(section)
                    )
                    .onTapGesture { selectedSection = section }
                }
            }

            Divider().background(Color.rBorder2).padding(.vertical, 8)

            // Supported platforms
            VStack(alignment: .leading, spacing: 6) {
                Text("SUPPORTED")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.rFg3)
                    .padding(.horizontal, 20)
                    .tracking(1.0)
                let platforms = ["YouTube","TikTok","Instagram","Twitter","Reddit","Vimeo","Twitch","+1000"]
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 4) {
                    ForEach(platforms, id: \.self) { p in
                        Text(p)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.rFg3)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.rSurface)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.rBorder2))
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 12)
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
        HStack(spacing: 9) {
            Image(systemName: section.icon)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .rFg : .rFg3)
                .frame(width: 20)
            Text(section.rawValue)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .rFg : .rFg2)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isSelected ? .rFg : .rFg3)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                    .cornerRadius(9)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
        .cornerRadius(6)
        .padding(.horizontal, 8)
    }
}

struct SidebarFooter: View {
    @EnvironmentObject var dm: DownloadManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundColor(.rFg3)
            VStack(alignment: .leading, spacing: 1) {
                Text(dm.outputFolder?.lastPathComponent ?? "No folder")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.rFg2)
                    .lineLimit(1)
            }
            Spacer()
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
```

---

### Task 3: URL Input Bar

**Files:**
- Modify: `Reel/ContentView.swift` (append)

- [ ] **Step 1: Add InputBar**

```swift
// MARK: - Input bar
struct InputBar: View {
    @Binding var urlText: String
    @Binding var format: DownloadFormat
    let addDownload: () -> Void

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
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.rSurface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.rBorder))
            .cornerRadius(8)

            // Format + Download
            HStack(spacing: 6) {
                // Segmented format control
                HStack(spacing: 0) {
                    ForEach(DownloadFormat.allCases) { f in
                        Button(f.rawValue.uppercased()) { format = f }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(format == f ? .rFg : .rFg3)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(format == f ? Color.white.opacity(0.1) : Color.clear)
                            .buttonStyle(.plain)
                        if f != DownloadFormat.allCases.last {
                            Divider().frame(height: 16).background(Color.rBorder)
                        }
                    }
                }
                .background(Color.rSurface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.rBorder))
                .cornerRadius(6)

                Spacer()

                Button(action: addDownload) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle.fill").font(.system(size: 12))
                        Text("Download").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color(hex: 0x0A0A0A))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(urlText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.rFg3 : Color.rFg)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .background(Color.rToolbar)
    }
}
```

---

### Task 4: Download Row

**Files:**
- Modify: `Reel/ContentView.swift` (append)

- [ ] **Step 1: Add DownloadRow**

```swift
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
                        .foregroundColor(.rFg)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        formatTag
                        Text(statusLabel)
                            .font(.system(size: 11))
                            .foregroundColor(.rFg3)
                    }
                }
                Spacer()
                actionButtons
            }

            if case .downloading = item.status {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 99).fill(Color.white.opacity(0.06)).frame(height: 2)
                            RoundedRectangle(cornerRadius: 99).fill(Color.rBlue).frame(width: geo.size.width * item.progress, height: 2)
                        }
                    }
                    .frame(height: 2)
                    HStack(spacing: 6) {
                        Text("\(Int(item.progress * 100))%")
                        if !item.speed.isEmpty { Text("·").opacity(0.3); Text(item.speed) }
                        if !item.eta.isEmpty   { Text("·").opacity(0.3); Text("ETA \(item.eta)") }
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
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.rBg)
        .overlay(Divider().background(Color.rBorder2), alignment: .bottom)
    }

    var formatTag: some View {
        let (bg, fg): (Color, Color) = {
            switch item.status {
            case .downloading: return (Color.rBlue.opacity(0.12), .rBlue)
            case .done:        return (Color.rGreen.opacity(0.12), .rGreen)
            case .failed:      return (Color.rRed.opacity(0.12),   .rRed)
            case .queued:      return (Color.rAmber.opacity(0.12), .rAmber)
            default:           return (Color.white.opacity(0.07),  .rFg3)
            }
        }()
        return Text(item.format.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundColor(fg)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(bg)
            .cornerRadius(3)
    }

    var statusLabel: String {
        switch item.status {
        case .queued:      return "Queued"
        case .fetching:    return "Getting info…"
        case .downloading: return "Downloading · \(Int(item.progress * 100))%"
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
                    .buttonStyle(DarkActionButtonStyle(isPrimary: true))
                Button { dm.remove(item) } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(DarkActionButtonStyle(isPrimary: false))
            case .failed:
                Button("Retry") {
                    let u = item.url; let f = item.format
                    dm.remove(item); dm.add(url: u, format: f)
                }
                .buttonStyle(DarkActionButtonStyle(isPrimary: false))
                Button { dm.remove(item) } label: { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(DarkActionButtonStyle(isPrimary: false))
            default:
                Button("Cancel") { dm.cancel(item) }
                    .buttonStyle(DarkActionButtonStyle(isPrimary: false))
            }
        }
    }
}

struct DarkActionButtonStyle: ButtonStyle {
    let isPrimary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isPrimary ? .rGreen : .rFg3)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(isPrimary ? Color.rGreen.opacity(0.1) : Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(isPrimary ? Color.rGreen.opacity(0.3) : Color.rBorder))
            .cornerRadius(5)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
```

---

### Task 5: Empty State, Status Bar, Detail View, Root View

**Files:**
- Modify: `Reel/ContentView.swift` (append remainder)

- [ ] **Step 1: Add EmptyStateView, StatusBar, DetailView, ContentView, FolderSetupView**

```swift
// MARK: - Empty state
struct EmptyStateView: View {
    let sites = ["YouTube","TikTok","Instagram","Twitter / X","Reddit","Vimeo","SoundCloud","Twitch","+1000 more"]
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.rSurface)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.rBorder))
                    .frame(width: 64, height: 64)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 28, weight: .thin))
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
    var activeCount:    Int { dm.items.filter { $0.status.isActive }.count }
    var completedCount: Int { dm.items.filter { if case .done = $0.status { return true }; return false }.count }

    var body: some View {
        HStack(spacing: 14) {
            if activeCount > 0 {
                HStack(spacing: 4) {
                    Circle().fill(Color.rAmber).frame(width: 5, height: 5)
                    Text("\(activeCount) active").font(.system(size: 10)).foregroundColor(.rFg3)
                }
            }
            if completedCount > 0 {
                HStack(spacing: 4) {
                    Circle().fill(Color.rGreen).frame(width: 5, height: 5)
                    Text("\(completedCount) completed").font(.system(size: 10)).foregroundColor(.rFg3)
                }
            }
            Spacer()
            Text("gallery-dl").font(.system(size: 10)).foregroundColor(.rFg3.opacity(0.5))
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(Color.rToolbar)
        .overlay(Divider().background(Color.rBorder2), alignment: .top)
    }
}

// MARK: - Detail view
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
            InputBar(urlText: $urlText, format: $format, addDownload: addDownload)
            Divider().background(Color.rBorder2)

            if filteredItems.isEmpty {
                if dm.items.isEmpty {
                    EmptyStateView().environmentObject(dm)
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
        .toolbar {
            ToolbarItem {
                if hasCompleted {
                    Button { dm.clearCompleted() } label: {
                        Text("Clear Completed")
                            .font(.system(size: 12))
                            .foregroundColor(.rFg3)
                    }
                    .buttonStyle(.plain)
                    .help("Remove done and failed items")
                }
            }
        }
    }
}

// MARK: - Folder setup sheet
struct FolderSetupView: View {
    @EnvironmentObject var dm: DownloadManager
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
                    .foregroundColor(Color(hex: 0x0A0A0A))
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
    }
}

// MARK: - Root content view
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
        case .completed: return dm.items.filter { switch $0.status { case .done, .failed: return true; default: return false } }
        }
    }

    func count(for section: SidebarSection) -> Int {
        switch section {
        case .all:       return dm.items.count
        case .active:    return dm.items.filter { $0.status.isActive }.count
        case .queued:    return dm.items.filter { if case .queued = $0.status { return true }; return false }.count
        case .completed: return dm.items.filter { switch $0.status { case .done, .failed: return true; default: return false } }.count
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
        .frame(minWidth: 720, minHeight: 480)
        .background(Color.rBg)
        .preferredColorScheme(.dark)
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
```

---

### Task 6: Generate New App Icon

**Files:**
- Run: `scripts/generate_icon.py`
- Modify: `Reel/Assets.xcassets/AppIcon.appiconset/*.png`

- [ ] **Step 1: Run icon generation script**

```python
#!/usr/bin/env python3
# scripts/generate_icon.py
from PIL import Image, ImageDraw, ImageFont
import os, math

def make_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Dark background fill (no rounding — macOS applies mask)
    d.rectangle([0, 0, size, size], fill=(10, 10, 10, 255))
    # Subtle radial gradient overlay
    cx, cy = size // 2, size // 2
    for r in range(cx, 0, -1):
        alpha = int(18 * (r / cx))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, alpha))
    # Merge with dark bg
    bg = Image.new("RGBA", (size, size), (10, 10, 10, 255))
    bg = Image.alpha_composite(bg, img)
    d2 = ImageDraw.Draw(bg)
    # Download arrow — shaft
    aw = max(4, size // 18)
    ax = size // 2
    shaft_top = int(size * 0.22)
    shaft_bot = int(size * 0.60)
    d2.rectangle([ax - aw//2, shaft_top, ax + aw//2, shaft_bot], fill=(240, 240, 240, 255))
    # Arrowhead
    ah = int(size * 0.22)
    hw = int(size * 0.28)
    pts = [
        (ax, shaft_bot + ah),
        (ax - hw, shaft_bot),
        (ax + hw, shaft_bot),
    ]
    d2.polygon(pts, fill=(240, 240, 240, 255))
    # Baseline bar
    bar_y = int(size * 0.76)
    bh = max(3, size // 22)
    bw = int(size * 0.46)
    d2.rectangle([ax - bw//2, bar_y, ax + bw//2, bar_y + bh], fill=(240, 240, 240, 255))
    return bg.convert("RGB")

sizes = [16, 32, 64, 128, 256, 512, 1024]
out = "Reel/Assets.xcassets/AppIcon.appiconset"
for s in sizes:
    img = make_icon(s)
    img.save(f"{out}/icon_{s}.png")
    print(f"  icon_{s}.png")

print("Done.")
```

Run with:
```bash
cd "/Users/ms/Downloads/Apps/Mac apps/Reel"
python3 scripts/generate_icon.py
```

---

### Task 7: Build, Push, Open

- [ ] **Step 1: Build the app**
```bash
cd "/Users/ms/Downloads/Apps/Mac apps/Reel"
xcodebuild -project Reel.xcodeproj -scheme Reel -configuration Release build 2>&1 | tail -5
```

- [ ] **Step 2: Commit and push**
```bash
cd "/Users/ms/Downloads/Apps/Mac apps/Reel"
git add -A
git commit -m "feat: Pure Dark redesign — new color system, sidebar, rows, icon"
git push origin main
```

- [ ] **Step 3: Open the app**
```bash
open "/Users/ms/Downloads/Apps/Mac apps/Reel/build/Release/Reel.app" 2>/dev/null || \
open "$(xcodebuild -project /Users/ms/Downloads/Apps/Mac\ apps/Reel/Reel.xcodeproj -scheme Reel -showBuildSettings 2>/dev/null | grep BUILT_PRODUCTS_DIR | awk '{print $3}')/Reel.app"
```
