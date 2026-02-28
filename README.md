# WhisprLocal

System-wide voice-to-text for macOS, powered by [whisper.cpp](https://github.com/ggml-org/whisper.cpp). Lives in your menu bar, runs 100% offline, supports 99+ languages.

**Press a hotkey, speak, and the transcribed text is pasted into whatever app you're using.**

## Features

- Fully offline — audio never leaves your Mac
- Menu bar app — no dock icon, always accessible
- Global hotkey (Option+D) — works in any app
- 99+ languages via OpenAI Whisper models
- Metal GPU acceleration on Apple Silicon and Intel

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.10+ (Xcode 15.3+ or Command Line Tools)
- A Whisper model file (see below)

## Quick Start

### 1. Build

```bash
git clone <repo-url>
cd WhisprLocal
./scripts/build-app.sh debug
```

This builds the `.app` bundle at `build/WhisprLocal.app`.

### 2. Download a model

Download a GGML Whisper model from [Hugging Face](https://huggingface.co/ggerganov/whisper.cpp/tree/main) and place it in the models folder:

```bash
mkdir -p ~/Library/Application\ Support/WhisprLocal/models
# Example: download the base model (~142 MB)
curl -L -o ~/Library/Application\ Support/WhisprLocal/models/ggml-base.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
```

### 3. Launch

```bash
open build/WhisprLocal.app
```

On first launch, grant **Microphone** and **Accessibility** permissions when prompted. Accessibility is needed to paste transcribed text into other apps.

> If you rebuild the app, you may need to toggle WhisprLocal OFF then ON in System Settings > Privacy & Security > Accessibility (the build script resets TCC entries automatically, but the toggle may appear stale).

## Models

| Model | File | Size | Notes |
|-------|------|------|-------|
| Tiny | `ggml-tiny.bin` | ~75 MB | Fastest, lower accuracy |
| **Base** | `ggml-base.bin` | **~142 MB** | **Recommended — good balance** |
| Small | `ggml-small.bin` | ~466 MB | Higher accuracy, moderate speed |
| Medium | `ggml-medium.bin` | ~1.5 GB | Best accuracy, slower |

Place model files in `~/Library/Application Support/WhisprLocal/models/`.

## Usage

1. Click the waveform icon in the menu bar, or press **Option+D**
2. Speak — the menu bar icon turns red while recording
3. Press **Option+D** again to stop
4. The text is transcribed (icon turns blue) and automatically pasted at your cursor

The hotkey can be customized in Settings (right-click the menu bar icon > Settings).

## How It Works

```
Option+D → AudioRecorder (16kHz mono)
         → WhisperTranscriber (whisper.cpp, Metal GPU)
         → TextInjector (clipboard + simulated Cmd+V)
         → Text appears at cursor
```

All processing happens on-device. No network calls, no telemetry.

## Project Structure

Built with Swift Package Manager (no `.xcodeproj`).

```
Sources/
  WhisprLocal/          App entry point, AppDelegate, MenuBarExtra scene
  WhisprLocalCore/      Business logic: audio recording, transcription, text injection
  WhisprLocalUI/        SwiftUI views: menu bar, settings, setup
Tests/
  WhisprLocalCoreTests/ Unit tests for core logic
scripts/
  build-app.sh          Builds the .app bundle with code signing
```

## Running Tests

Tests require Xcode (not just Command Line Tools):

```bash
swift test
```

To run a specific test class:

```bash
swift test --filter WhisprLocalCoreTests.AppStateTests
```

## Acknowledgements

- [whisper.cpp](https://github.com/ggml-org/whisper.cpp) — C/C++ port of OpenAI's Whisper model
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — Global keyboard shortcuts for macOS

## License

MIT License. See [LICENSE](LICENSE) for details.
