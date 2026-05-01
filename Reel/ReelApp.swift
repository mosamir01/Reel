import SwiftUI

@main
struct ReelApp: App {
    @StateObject private var dm = DownloadManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dm)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
