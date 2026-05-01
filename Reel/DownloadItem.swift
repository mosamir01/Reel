import Foundation

enum DownloadStatus: Equatable {
    case queued, fetching, downloading, converting, done, failed(String)
    static func == (l: DownloadStatus, r: DownloadStatus) -> Bool {
        switch (l, r) {
        case (.queued,.queued),(.fetching,.fetching),(.downloading,.downloading),
             (.converting,.converting),(.done,.done): return true
        case (.failed(let a),.failed(let b)): return a == b
        default: return false
        }
    }
    var isActive: Bool {
        switch self { case .fetching,.downloading,.converting: return true; default: return false }
    }
}

enum DownloadFormat: String, CaseIterable, Identifiable {
    case best = "Best"
    case mp4  = "MP4"
    case mp3  = "MP3"
    case wav  = "WAV"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .best: return "Best Quality (video+audio)"
        case .mp4:  return "MP4 Video"
        case .mp3:  return "MP3 Audio"
        case .wav:  return "WAV Audio"
        }
    }
}

@MainActor
class DownloadItem: ObservableObject, Identifiable {
    let id = UUID()
    let url: String
    let format: DownloadFormat
    @Published var title: String
    @Published var status: DownloadStatus = .queued
    @Published var progress: Double = 0
    @Published var speed: String = ""
    @Published var eta: String = ""
    @Published var filePath: String?
    var process: Process?

    init(url: String, format: DownloadFormat) {
        self.url = url
        self.format = format
        self.title = URL(string: url)?.host ?? url
    }
}
