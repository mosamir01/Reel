# 🎬 Reel

A clean macOS app for downloading video and audio from **1000+ websites** — YouTube, TikTok, Instagram, Twitter/X, Reddit, Vimeo, SoundCloud, Twitch, and more.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Paste any URL** — supports 1000+ sites via yt-dlp
- **Format picker** — Best Quality, MP4 video, MP3 audio, WAV audio
- **Live progress** — per-download progress bar with speed and ETA
- **Concurrent downloads** — up to 3 at once
- **One-click open** — open the file or folder when done
- **Retry on failure** — one click to retry failed downloads
- **Remembers your folder** — asks once on first launch, saves it

## Requirements

- macOS 13 or later
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) installed

```bash
brew install yt-dlp
```

> **Optional:** Install `ffmpeg` for best-quality video+audio merging:
> ```bash
> brew install ffmpeg
> ```

## Build

Open `Reel.xcodeproj` in Xcode 15+ and hit Run, or:

```bash
xcodebuild -scheme Reel -configuration Release build
```

## How it works

Reel is a native SwiftUI wrapper around [yt-dlp](https://github.com/yt-dlp/yt-dlp), the powerful open-source media downloader. It passes your URL and format choice to yt-dlp, parses the live progress output, and presents it in a clean Mac-native interface.

## Supported Sites (sample)

YouTube · TikTok · Instagram · Twitter/X · Reddit · Facebook · Vimeo · SoundCloud · Twitch · Dailymotion · Bilibili · Rumble · Odysee · Pinterest · LinkedIn · and [1000+ more](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)

## License

MIT
