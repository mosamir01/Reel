import SwiftUI
import AppKit

// MARK: - Dock icon animator

@MainActor
final class DockAnimator {
    private var timer: Timer?
    private var angle: CGFloat = 0
    private var baseIcon: NSImage?
    private var wasActive = false

    func observe(_ dm: DownloadManager) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self, weak dm] _ in
            guard let self, let dm else { return }
            self.tick(dm: dm)
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        NSApp.applicationIconImage = nil
    }

    private func tick(dm: DownloadManager) {
        let isActive = dm.items.contains { $0.status.isActive }

        let justCompleted = wasActive && !isActive && dm.items.contains {
            if case .done = $0.status { return true }
            return false
        }
        wasActive = isActive

        if justCompleted {
            NSApp.requestUserAttention(.informationalRequest)
        }

        if isActive {
            if baseIcon == nil { baseIcon = NSApp.applicationIconImage }
            angle += 3   // 3°/frame × 30fps = 90°/sec — one full spin every 4s
            if angle >= 360 { angle -= 360 }
            if let base = baseIcon {
                NSApp.applicationIconImage = rotated(base, by: angle)
            }
        } else if baseIcon != nil {
            NSApp.applicationIconImage = nil
            baseIcon = nil
            angle = 0
        }
    }

    private func rotated(_ image: NSImage, by degrees: CGFloat) -> NSImage {
        let size = image.size
        let result = NSImage(size: size)
        result.lockFocus()
        defer { result.unlockFocus() }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.rotate(by: -degrees * .pi / 180)   // negative = clockwise

        image.draw(in: NSRect(x: -size.width / 2, y: -size.height / 2,
                              width: size.width, height: size.height),
                   from: .zero, operation: .sourceOver, fraction: 1)

        return result
    }
}

// MARK: - App

@main
struct ReelApp: App {
    @StateObject private var dm = DownloadManager()
    private let animator = DockAnimator()

    init() {}

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dm)
                .onAppear { animator.observe(dm) }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
