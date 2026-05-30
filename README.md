# Reel

A clean macOS app for downloading video and audio from **1000+ websites** — YouTube, TikTok, Instagram, Twitter/X, Reddit, Vimeo, SoundCloud, Twitch, and more.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Download

**[Download Reel.dmg](https://github.com/mosamir01/Reel/releases/latest/download/Reel.dmg)**

No Homebrew. No terminal. No setup. Just open and paste a link.

## Features

- **No dependencies** — everything is bundled inside the app
- **Paste any URL** — YouTube, TikTok, Instagram, Twitter/X, Reddit, Vimeo, SoundCloud, Twitch, and 1000+ more
- **Format picker** — Best Quality, MP4, MP3, WAV
- **Faster downloads** — parallel connections for faster speeds
- **Live progress** — speed, ETA, and status per download
- **Up to 3 concurrent downloads**
- **One-click open** — open the file or folder when done
- **Retry on failure** — one click to retry
- **Remembers your folder** — set once, never asked again

## Requirements

- macOS 13 or later

## Build from Source

```bash
git clone https://github.com/mosamir01/Reel.git
cd Reel
open Reel.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -scheme Reel -configuration Release build
```

## How it works

Reel bundles [yt-dlp](https://github.com/yt-dlp/yt-dlp) directly inside the app — no separate installation needed. It passes your URL and format choice to yt-dlp, uses parallel connections for faster downloads, parses the live progress output, and presents everything in a clean Mac-native interface.

## Supported Sites

YouTube · TikTok · Instagram · Twitter/X · Reddit · Facebook · Vimeo · SoundCloud · Twitch · Dailymotion · Bilibili · Rumble · Odysee · Pinterest · LinkedIn · and [1000+ more](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)

## License

MIT
