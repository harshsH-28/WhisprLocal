# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release

# Build .app bundle (creates build/WhisprLocal.app)
./scripts/build-app.sh debug    # or: ./scripts/build-app.sh release

# Run tests (requires Xcode, not just Command Line Tools)
xcode-select -s /Applications/Xcode.app/Contents/Developer && swift test

# Run a single test
swift test --filter WhisprLocalCoreTests.AppStateTests
swift test --filter WhisprLocalCoreTests.AppStateTests/testSpecificMethod
```

No linter is configured.

## Architecture

macOS menu bar app for 100% offline voice-to-text using whisper.cpp. No network, no cloud.

### Targets

| Target | Type | Purpose |
|--------|------|---------|
| `WhisprLocal` | executable | App entry point, `@main`, AppDelegate, MenuBarExtra scene |
| `WhisprLocalCore` | library | All business logic, services, models — the testable core |
| `WhisprLocalUI` | library | SwiftUI views (MenuBarView, SettingsView, SetupView) |
| `WhisprLocalCoreTests` | test | XCTest suite (8 files, one per service/model) |

### Core Pipeline

```
User presses Option+D → HotkeyManager
  → DictationController.toggleDictation()
    → AudioRecorder (AVAudioEngine, 16kHz mono Float32)
    → WhisperTranscriber (actor, whisper.cpp C API, greedy sampling)
    → TextInjector (clipboard save → paste via simulated Cmd+V → clipboard restore)
```

`DictationController` is the central orchestrator. `AppState` (@Observable) drives all UI via a `RecordingState` state machine (.idle → .recording → .transcribing → .idle/.error).

### Key Design Decisions

- **SPM-only** — no .xcodeproj. Build from command line with `swift build`.
- **Actor for transcriber** — `WhisperTranscriber` is a Swift actor wrapping whisper.cpp's C `OpaquePointer` context. Thread-safe without manual locks.
- **No sandbox** — text injection uses CGEvent/accessibility APIs that require unsandboxed access.
- **LSUIElement=true** — menu bar only, no dock icon.
- **Ad-hoc code signing** — each rebuild creates a new code identity. `build-app.sh` clears TCC entries (`tccutil reset`) so macOS re-prompts for permissions.
- **Manual model placement** — users download GGML models and place them at `~/Library/Application Support/WhisprLocal/models/ggml-{size}.bin` (tiny/base/small/medium).

### Dependencies

- **whisper.cpp v1.8.3** — binary XCFramework from ggml-org releases. Linked only by `WhisprLocalCore`.
- **KeyboardShortcuts v1.7.0** — **pinned**. v2.0.0+ uses `#Preview` macros that break `swift build` without Xcode.

### Permissions

Two runtime permissions required:
- **Microphone** — `AVCaptureDevice.requestAccess` for audio recording
- **Accessibility** — `AXIsProcessTrusted()` for text injection via simulated keystrokes

`PermissionManager` handles checks/requests. AppDelegate polls `refreshStatus()` every 2s to keep UI in sync with System Settings.
