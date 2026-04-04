# WhisprLocal v2 Rehaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform WhisprLocal from a functional prototype into a polished, reliable macOS menu bar app with proper icon, CI/CD, sleep/wake resilience, redesigned UI, and robust model management.

**Architecture:** Extend existing SPM-based three-target architecture (WhisprLocal, WhisprLocalCore, WhisprLocalUI). Add sleep/wake handlers and audio engine reset to core. Redesign all three SwiftUI views. Add GitHub Actions for CI and tagged releases. Convert user-provided PNG to .icns for app icon.

**Tech Stack:** Swift 5.10, SwiftUI, AVFoundation, whisper.cpp v1.8.3, KeyboardShortcuts 1.7.0, GitHub Actions, macOS 14+

---

## Task 1: App Icon — Convert PNG to .icns and Wire Into Bundle

**Files:**
- Create: `Resources/AppIcon.icns`
- Modify: `Resources/Info.plist`
- Modify: `scripts/build-app.sh`

- [ ] **Step 1: Generate .iconset from source PNG**

```bash
# Create iconset directory
mkdir -p /tmp/AppIcon.iconset

# Source image (must be at least 1024x1024)
SOURCE="/Users/harshsh/.claude/image-cache/8e0e3102-d485-4528-8f92-71b341f7eb59/1.png"

# Generate all required sizes
sips -z 16 16     "$SOURCE" --out /tmp/AppIcon.iconset/icon_16x16.png
sips -z 32 32     "$SOURCE" --out /tmp/AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     "$SOURCE" --out /tmp/AppIcon.iconset/icon_32x32.png
sips -z 64 64     "$SOURCE" --out /tmp/AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   "$SOURCE" --out /tmp/AppIcon.iconset/icon_128x128.png
sips -z 256 256   "$SOURCE" --out /tmp/AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   "$SOURCE" --out /tmp/AppIcon.iconset/icon_256x256.png
sips -z 512 512   "$SOURCE" --out /tmp/AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   "$SOURCE" --out /tmp/AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 "$SOURCE" --out /tmp/AppIcon.iconset/icon_512x512@2x.png
```

- [ ] **Step 2: Create .icns file and copy to Resources**

```bash
iconutil -c icns /tmp/AppIcon.iconset -o Resources/AppIcon.icns
rm -rf /tmp/AppIcon.iconset
```

Verify: `file Resources/AppIcon.icns` should output "Mac OS X icon"

- [ ] **Step 3: Add CFBundleIconFile to Info.plist**

In `Resources/Info.plist`, add before the closing `</dict>`:

```xml
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
```

- [ ] **Step 4: Update build-app.sh to copy icon into bundle**

In `scripts/build-app.sh`, after line 60 (`cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"`), add:

```bash
# Copy app icon
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    echo "Copied app icon"
fi
```

- [ ] **Step 5: Verify icon works**

```bash
./scripts/build-app.sh debug
# Check icon is in bundle
ls -la build/WhisprLocal.app/Contents/Resources/AppIcon.icns
# Check Info.plist has icon key
/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" build/WhisprLocal.app/Contents/Info.plist
# Expected: AppIcon
```

- [ ] **Step 6: Commit**

```bash
git add Resources/AppIcon.icns Resources/Info.plist scripts/build-app.sh
git commit -m "feat: add app icon from user-provided retro CRT pixel art design"
```

---

## Task 2: RecordingState — Add idle → error Transition

**Files:**
- Modify: `Sources/WhisprLocalCore/Models/RecordingState.swift`
- Modify: `Tests/WhisprLocalCoreTests/AppStateTests.swift`

- [ ] **Step 1: Write failing test for idle → error transition**

Add to `Tests/WhisprLocalCoreTests/AppStateTests.swift`:

```swift
func testIdleToErrorTransition() {
    let state = AppState()
    // idle → error must be valid (e.g., sleep interruption message, startRecording failure)
    let result = state.transition(to: .error("test error from idle"))
    XCTAssertTrue(result)
    XCTAssertTrue(state.recordingState.isError)
    XCTAssertEqual(state.lastError, "test error from idle")
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcode-select -s /Applications/Xcode.app/Contents/Developer && swift test --filter WhisprLocalCoreTests.AppStateTests/testIdleToErrorTransition
```

Expected: FAIL — idle → error transition returns false.

- [ ] **Step 3: Add idle → error transition to RecordingState**

In `Sources/WhisprLocalCore/Models/RecordingState.swift`, add after line 34 (`case (.error, .idle):`):

```swift
        case (.idle, .error):             // error from idle (e.g., sleep interruption, failed start)
            return true
```

- [ ] **Step 4: Run test to verify it passes**

```bash
swift test --filter WhisprLocalCoreTests.AppStateTests/testIdleToErrorTransition
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/WhisprLocalCore/Models/RecordingState.swift Tests/WhisprLocalCoreTests/AppStateTests.swift
git commit -m "fix: allow idle → error state transition for sleep interruption and start failures"
```

---

## Task 3: AppState — Add Download State Properties for Multi-Model Management

**Files:**
- Modify: `Sources/WhisprLocalCore/Models/AppState.swift`
- Modify: `Tests/WhisprLocalCoreTests/AppStateTests.swift`

- [ ] **Step 1: Write failing tests for new AppState properties**

Add to `Tests/WhisprLocalCoreTests/AppStateTests.swift`:

```swift
func testDownloadStateInitialValues() {
    let state = AppState()
    XCTAssertNil(state.downloadingModelType)
    XCTAssertNil(state.downloadProgress)
    XCTAssertNil(state.downloadError)
    XCTAssertFalse(state.isDownloading)
}

func testIsDownloadingDerivedFromDownloadingModelType() {
    let state = AppState()
    state.downloadingModelType = .base
    state.downloadProgress = 0.5
    XCTAssertTrue(state.isDownloading)

    state.downloadingModelType = nil
    state.downloadProgress = nil
    XCTAssertFalse(state.isDownloading)
}

func testSetupCompleteWithAnyModelInstalled() {
    let state = AppState()
    state.hasMicrophonePermission = true
    state.hasAccessibilityPermission = true
    state.isModelAvailable = true
    XCTAssertTrue(state.isSetupComplete)
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcode-select -s /Applications/Xcode.app/Contents/Developer && swift test --filter WhisprLocalCoreTests.AppStateTests
```

Expected: FAIL — `downloadingModelType` and `downloadError` don't exist yet.

- [ ] **Step 3: Update AppState with new properties**

Replace the full `AppState.swift` with:

```swift
import Foundation
import SwiftUI

/// Observable application state shared across the app.
@Observable
public final class AppState {
    /// Current recording/transcription state.
    public var recordingState: RecordingState = .idle

    /// The currently selected whisper model type.
    public var selectedModelType: WhisperModelType = .base

    /// Whether a model is currently loaded in memory.
    public var isModelLoaded: Bool = false

    /// The last transcribed text.
    public var lastTranscription: String = ""

    /// Last error message, if any.
    public var lastError: String?

    /// Whether microphone permission has been granted.
    public var hasMicrophonePermission: Bool = false

    /// Whether accessibility permission has been granted.
    public var hasAccessibilityPermission: Bool = false

    /// Whether the selected model file exists on disk.
    public var isModelAvailable: Bool = false

    /// Selected language for transcription. "auto" = whisper auto-detect.
    public var selectedLanguage: String = "auto"

    /// Which model is currently being downloaded (nil = no download in progress).
    public var downloadingModelType: WhisperModelType?

    /// Download progress for the current download (0.0–1.0).
    public var downloadProgress: Double?

    /// Error message from the last failed download attempt.
    public var downloadError: String?

    /// Whether a model download is currently in progress.
    public var isDownloading: Bool { downloadingModelType != nil }

    /// Whether initial setup is complete (all permissions granted and model available).
    public var isSetupComplete: Bool {
        hasMicrophonePermission && hasAccessibilityPermission && isModelAvailable
    }

    public init() {}

    /// Attempt to transition recording state, returning success.
    @discardableResult
    public func transition(to newState: RecordingState) -> Bool {
        guard recordingState.canTransition(to: newState) else { return false }
        recordingState = newState
        if case .error(let message) = newState {
            lastError = message
        }
        return true
    }

    /// Reset error state back to idle.
    public func clearError() {
        if recordingState.isError {
            recordingState = .idle
        }
        lastError = nil
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter WhisprLocalCoreTests.AppStateTests
```

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/WhisprLocalCore/Models/AppState.swift Tests/WhisprLocalCoreTests/AppStateTests.swift
git commit -m "feat: add download state properties to AppState for multi-model management"
```

---

## Task 4: AudioRecorder — Add resetEngine() Method

**Files:**
- Modify: `Sources/WhisprLocalCore/Services/AudioRecorder.swift`

- [ ] **Step 1: Add resetEngine method**

In `AudioRecorder.swift`, change line 23 from `private let engine = AVAudioEngine()` to:

```swift
private var engine = AVAudioEngine()
```

Then add after the `cancelRecording()` method (after line 128):

```swift
    /// Reset the audio engine after sleep/wake or error recovery.
    /// Creates a fresh AVAudioEngine instance to recover from zombie state.
    public func resetEngine() {
        if isRecording {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            isRecording = false
        }
        lock.lock()
        samples.removeAll()
        lock.unlock()
        engine = AVAudioEngine()
    }
```

- [ ] **Step 2: Build to verify compilation**

```bash
swift build
```

Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/WhisprLocalCore/Services/AudioRecorder.swift
git commit -m "feat: add resetEngine() to AudioRecorder for sleep/wake recovery"
```

---

## Task 5: DictationController — Fix State Ordering and Add Sleep/Wake Support

**Files:**
- Modify: `Sources/WhisprLocalCore/DictationController.swift`

- [ ] **Step 1: Fix startRecording state ordering and add sleep support**

Replace the full `DictationController.swift`:

```swift
import Foundation

/// Orchestrates the full dictation pipeline: record → transcribe → paste.
@Observable
public final class DictationController {
    private let audioRecorder: AudioRecorder
    private let transcriber: WhisperTranscriber
    private let textInjector: TextInjector
    public let modelManager: ModelManager
    private let hotkeyManager: HotkeyManager

    /// Set by AppDelegate on sleep if recording was active.
    public var wasInterruptedBySleep: Bool = false

    public let appState: AppState

    public init(
        appState: AppState = AppState(),
        audioRecorder: AudioRecorder = AudioRecorder(),
        transcriber: WhisperTranscriber = WhisperTranscriber(),
        textInjector: TextInjector = TextInjector(),
        modelManager: ModelManager = ModelManager(),
        hotkeyManager: HotkeyManager = HotkeyManager()
    ) {
        self.appState = appState
        self.audioRecorder = audioRecorder
        self.transcriber = transcriber
        self.textInjector = textInjector
        self.modelManager = modelManager
        self.hotkeyManager = hotkeyManager
    }

    /// Set up hotkey and initial state.
    public func setup() {
        hotkeyManager.register { [weak self] in
            self?.toggleDictation()
        }
    }

    /// Toggle dictation: start if idle, stop if recording.
    public func toggleDictation() {
        switch appState.recordingState {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .error:
            appState.clearError()
        default:
            break
        }
    }

    /// Begin recording audio.
    public func startRecording() {
        guard appState.recordingState.isIdle else { return }

        do {
            try audioRecorder.startRecording()
            // Only transition to .recording AFTER the engine successfully starts
            appState.transition(to: .recording)
        } catch {
            appState.transition(to: .error("Failed to start recording: \(error.localizedDescription)"))
        }
    }

    /// Stop recording and begin transcription pipeline.
    public func stopRecording() {
        // Verify both AppState and AudioRecorder agree we're recording
        guard appState.recordingState.isRecording else { return }

        guard audioRecorder.isRecording else {
            // State out of sync — reset to idle
            appState.transition(to: .idle)
            return
        }

        do {
            let samples = try audioRecorder.stopRecording()
            appState.transition(to: .transcribing)

            Task {
                await transcribeAndInject(samples: samples)
            }
        } catch {
            appState.transition(to: .error("Failed to stop recording: \(error.localizedDescription)"))
        }
    }

    /// Cancel current recording without transcribing.
    public func cancelRecording() {
        audioRecorder.cancelRecording()
        appState.transition(to: .idle)
    }

    /// Reset the audio engine (called after sleep/wake).
    public func resetAudioEngine() {
        audioRecorder.resetEngine()
    }

    /// Load the selected model if not already loaded.
    public func ensureModelLoaded() async throws {
        guard !appState.isModelLoaded else { return }

        let modelPath = modelManager.modelPath(for: appState.selectedModelType)
        guard modelManager.isModelAvailable(appState.selectedModelType) else {
            throw TranscriberError.modelLoadFailed(modelPath.path)
        }

        try await transcriber.loadModel(path: modelPath.path)
        appState.isModelLoaded = true
    }

    /// Unload the current model from memory.
    public func unloadModel() async {
        await transcriber.unloadModel()
        appState.isModelLoaded = false
    }

    /// Refresh permission and model status.
    public func refreshStatus() {
        let permissionManager = PermissionManager()
        appState.hasMicrophonePermission = permissionManager.checkMicrophonePermission()
        appState.hasAccessibilityPermission = permissionManager.checkAccessibilityPermission()
        appState.isModelAvailable = modelManager.isModelAvailable(appState.selectedModelType)
    }

    // MARK: - Private

    private func transcribeAndInject(samples: [Float]) async {
        do {
            try await ensureModelLoaded()

            let language = await MainActor.run { self.appState.selectedLanguage }
            let text = try await transcriber.transcribe(samples: samples, language: language)

            _ = await MainActor.run {
                self.appState.lastTranscription = text
            }

            await MainActor.run { self.refreshStatus() }

            if !text.isEmpty {
                try await textInjector.inject(text: text)
            }

            _ = await MainActor.run {
                self.appState.transition(to: .idle)
            }
        } catch {
            _ = await MainActor.run {
                self.appState.transition(to: .error("Transcription failed: \(error.localizedDescription)"))
            }
        }
    }
}
```

Key changes from original:
- `modelManager` is now `public let` — views must use `controller.modelManager` instead of creating new instances (fixes cancel/delete operating on wrong instance)
- `startRecording()`: transitions to `.recording` AFTER `audioRecorder.startRecording()` succeeds (not before). Requires Task 2's idle → error transition for the catch block to work.
- `stopRecording()`: checks `audioRecorder.isRecording` for sync verification
- `toggleDictation()`: error state clears on hotkey press (QOL)
- Added `wasInterruptedBySleep` property
- Added `resetAudioEngine()` method

- [ ] **Step 2: Build to verify compilation**

```bash
swift build
```

Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/WhisprLocalCore/DictationController.swift
git commit -m "fix: state ordering in DictationController and add sleep/wake support"
```

---

## Task 6: AppDelegate — Sleep/Wake Handlers and Single-Instance Check

**Files:**
- Modify: `Sources/WhisprLocal/AppDelegate.swift`

- [ ] **Step 1: Rewrite AppDelegate with sleep/wake handlers**

Replace the full `AppDelegate.swift`:

```swift
import AppKit
import SwiftUI
import WhisprLocalCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DictationController()
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance check: if already running, activate existing and quit
        let bundleID = Bundle.main.bundleIdentifier ?? "com.whisprlocal.app"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            // Another instance is already running — activate it and quit self
            for app in running where app != NSRunningApplication.current {
                app.activate()
            }
            NSApp.terminate(nil)
            return
        }

        controller.refreshStatus()
        controller.setup()

        // Clean up orphaned temp files from failed downloads
        controller.modelManager.cleanupOrphanedFiles()

        let permissionManager = PermissionManager()
        if !permissionManager.checkAccessibilityPermission() {
            permissionManager.requestAccessibilityPermission()
        }

        startPermissionPolling()
        registerSleepWakeNotifications()

        if controller.appState.isModelAvailable {
            Task {
                try? await controller.ensureModelLoaded()
            }
        }
    }

    /// Polls permissions every 2 seconds so the UI stays in sync with System Settings.
    private func startPermissionPolling() {
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.controller.refreshStatus()
        }
    }

    // MARK: - Sleep/Wake

    private func registerSleepWakeNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(handleSleep),
                           name: NSWorkspace.screensDidSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(handleWake),
                           name: NSWorkspace.screensDidWakeNotification, object: nil)
    }

    @objc private func handleSleep() {
        if controller.appState.recordingState.isRecording {
            controller.stopRecording()
            controller.wasInterruptedBySleep = true
        }
    }

    @objc private func handleWake() {
        // Reset audio engine to recover from zombie state
        controller.resetAudioEngine()

        if controller.wasInterruptedBySleep {
            // Only show interruption message if transcription has already completed.
            // If still transcribing, let it finish — the message would conflict with the
            // transcribing → idle transition.
            if !controller.appState.recordingState.isTranscribing {
                controller.appState.transition(to: .error(
                    "Recording was interrupted because the system went to sleep. Partial transcription was saved."
                ))
            }
            controller.wasInterruptedBySleep = false
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        controller.cancelRecording()
        controller.modelManager.cancelDownload()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
swift build
```

Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/WhisprLocal/AppDelegate.swift
git commit -m "feat: add sleep/wake handlers and single-instance check to AppDelegate"
```

---

## Task 7: ModelManager — Concurrent Prevention, Cancel Cleanup, Orphan Cleanup

**Files:**
- Modify: `Sources/WhisprLocalCore/Services/ModelManager.swift`

- [ ] **Step 1: Update ModelManager with robustness improvements**

Add a new error case to `ModelManagerError` enum (after `case invalidDownload`):

```swift
    case downloadInProgress
```

And its description in `errorDescription`:

```swift
        case .downloadInProgress:
            return "A download is already in progress"
```

Add a concurrent download guard at the top of `downloadModel()` (line 130, before `try ensureModelsDirectory()`):

```swift
    guard downloadTask == nil else { throw ModelManagerError.downloadInProgress }
```

Add the `cleanupOrphanedFiles()` method after `cancelDownload()` (after line 167):

```swift
    /// Clean up orphaned temp files from failed/cancelled downloads.
    public func cleanupOrphanedFiles() {
        let tempDir = fileManager.temporaryDirectory
        guard let contents = try? fileManager.contentsOfDirectory(
            at: tempDir, includingPropertiesForKeys: nil
        ) else { return }

        for file in contents where file.pathExtension == "bin" {
            // UUID-named .bin files are our download artifacts
            let name = file.deletingPathExtension().lastPathComponent
            if UUID(uuidString: name) != nil {
                try? fileManager.removeItem(at: file)
            }
        }
    }
```

Update `cancelDownload()` to clean up temp files:

```swift
    /// Cancel an in-flight download.
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        progressCallback = nil
    }
```

(This stays the same — the URLSession delegate handles cleanup when cancel triggers `didCompleteWithError`.)

- [ ] **Step 2: Build to verify compilation**

```bash
swift build
```

Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/WhisprLocalCore/Services/ModelManager.swift
git commit -m "feat: add download guard, orphan cleanup, and improved error types to ModelManager"
```

---

## Task 8: MenuBarView — Full Redesign

**Files:**
- Modify: `Sources/WhisprLocalUI/MenuBarView.swift`

- [ ] **Step 1: Rewrite MenuBarView**

Replace the full `MenuBarView.swift`:

```swift
import KeyboardShortcuts
import SwiftUI
import WhisprLocalCore

public struct MenuBarView: View {
    let controller: DictationController
    @State private var showCopiedFeedback = false

    public init(controller: DictationController) {
        self.controller = controller
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Status header
                StatusSection(
                    state: controller.appState.recordingState,
                    modelName: controller.appState.isModelLoaded
                        ? controller.appState.selectedModelType.displayName : nil
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Error banner (shown when in error state)
                if case .error(let message) = controller.appState.recordingState {
                    ErrorBanner(message: message) {
                        controller.appState.clearError()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                // Setup prompt if not ready
                if !controller.appState.isSetupComplete,
                   !controller.appState.recordingState.isRecording,
                   !controller.appState.recordingState.isTranscribing {
                    Divider().padding(.horizontal, 16)
                    SetupPromptSection(appState: controller.appState)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                // Last transcription
                if !controller.appState.lastTranscription.isEmpty,
                   !controller.appState.recordingState.isRecording,
                   !controller.appState.recordingState.isTranscribing {
                    Divider().padding(.horizontal, 16)
                    LastTranscriptionSection(
                        text: controller.appState.lastTranscription,
                        showCopiedFeedback: $showCopiedFeedback
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // Shortcut hint (only when idle)
                if controller.appState.recordingState.isIdle {
                    Divider().padding(.horizontal, 16)
                    ShortcutSection()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }

                // Footer
                Divider().padding(.horizontal, 16)
                FooterSection()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .frame(width: 320, maxHeight: 400)
    }
}

// MARK: - Sub-sections

private struct StatusSection: View {
    let state: RecordingState
    let modelName: String?

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            if let modelName, state.isIdle {
                Text("\(modelName) model loaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if state.isRecording {
                Text("Press ⌥D to stop")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if state.isTranscribing {
                Text("Just a moment")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dotColor: Color {
        switch state {
        case .idle: return .green
        case .recording: return .red
        case .transcribing: return .blue
        case .error: return .orange
        }
    }

    private var statusText: String {
        switch state {
        case .idle: return "Ready"
        case .recording: return "Recording..."
        case .transcribing: return "Transcribing..."
        case .error: return "Error"
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)

            Button("Dismiss", action: onDismiss)
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct SetupPromptSection: View {
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !appState.hasMicrophonePermission {
                Label("Microphone permission needed", systemImage: "mic.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if !appState.hasAccessibilityPermission {
                Label("Accessibility permission needed", systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if !appState.isModelAvailable {
                Label("Whisper model not found", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            SettingsLink {
                Text("Open Setup...")
            }
            .font(.caption)
        }
    }
}

private struct LastTranscriptionSection: View {
    let text: String
    @Binding var showCopiedFeedback: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Last Transcription")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    showCopiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCopiedFeedback = false
                    }
                } label: {
                    Text(showCopiedFeedback ? "Copied!" : "Copy")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(8)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct ShortcutSection: View {
    var body: some View {
        HStack {
            Text("Shortcut")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("⌥D")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

private struct FooterSection: View {
    var body: some View {
        HStack {
            SettingsLink {
                Text("Settings...")
            }
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .foregroundStyle(.secondary)
        }
        .font(.caption)
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
swift build
```

Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/WhisprLocalUI/MenuBarView.swift
git commit -m "feat: redesign MenuBarView with scrollable transcription, copy button, error display"
```

---

## Task 9: SettingsView — Full Redesign with Multi-Model Management

**Files:**
- Modify: `Sources/WhisprLocalUI/SettingsView.swift`

- [ ] **Step 1: Rewrite SettingsView**

Replace the full `SettingsView.swift`:

```swift
import KeyboardShortcuts
import SwiftUI
import WhisprLocalCore

public struct SettingsView: View {
    let controller: DictationController
    @State private var selectedTab = 0

    public init(controller: DictationController) {
        self.controller = controller
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(controller: controller)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            ModelSettingsTab(controller: controller)
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
                .tag(1)

            SetupView(controller: controller, selectedTab: $selectedTab)
                .tabItem {
                    Label("Setup", systemImage: "checkmark.circle")
                }
                .tag(2)
        }
        .frame(width: 520, height: 440)
    }
}

// MARK: - General Settings

private struct GeneralSettingsTab: View {
    let controller: DictationController
    @State private var showAllLanguages = false

    private static let commonLanguages: [(code: String, name: String)] = [
        ("auto", "Auto-Detect"),
        ("en", "English"),
        ("zh", "Chinese"),
        ("de", "German"),
        ("es", "Spanish"),
        ("ru", "Russian"),
        ("ko", "Korean"),
        ("fr", "French"),
        ("ja", "Japanese"),
        ("pt", "Portuguese"),
        ("tr", "Turkish"),
        ("pl", "Polish"),
        ("it", "Italian"),
        ("hi", "Hindi"),
        ("ar", "Arabic"),
        ("nl", "Dutch"),
    ]

    private static let allLanguages: [(code: String, name: String)] = [
        ("auto", "Auto-Detect"),
        ("af", "Afrikaans"), ("am", "Amharic"), ("ar", "Arabic"), ("as", "Assamese"),
        ("az", "Azerbaijani"), ("ba", "Bashkir"), ("be", "Belarusian"), ("bg", "Bulgarian"),
        ("bn", "Bengali"), ("bo", "Tibetan"), ("br", "Breton"), ("bs", "Bosnian"),
        ("ca", "Catalan"), ("cs", "Czech"), ("cy", "Welsh"), ("da", "Danish"),
        ("de", "German"), ("el", "Greek"), ("en", "English"), ("es", "Spanish"),
        ("et", "Estonian"), ("eu", "Basque"), ("fa", "Persian"), ("fi", "Finnish"),
        ("fo", "Faroese"), ("fr", "French"), ("gl", "Galician"), ("gu", "Gujarati"),
        ("ha", "Hausa"), ("haw", "Hawaiian"), ("he", "Hebrew"), ("hi", "Hindi"),
        ("hr", "Croatian"), ("ht", "Haitian Creole"), ("hu", "Hungarian"), ("hy", "Armenian"),
        ("id", "Indonesian"), ("is", "Icelandic"), ("it", "Italian"), ("ja", "Japanese"),
        ("jw", "Javanese"), ("ka", "Georgian"), ("kk", "Kazakh"), ("km", "Khmer"),
        ("kn", "Kannada"), ("ko", "Korean"), ("la", "Latin"), ("lb", "Luxembourgish"),
        ("ln", "Lingala"), ("lo", "Lao"), ("lt", "Lithuanian"), ("lv", "Latvian"),
        ("mg", "Malagasy"), ("mi", "Maori"), ("mk", "Macedonian"), ("ml", "Malayalam"),
        ("mn", "Mongolian"), ("mr", "Marathi"), ("ms", "Malay"), ("mt", "Maltese"),
        ("my", "Myanmar"), ("ne", "Nepali"), ("nl", "Dutch"), ("nn", "Nynorsk"),
        ("no", "Norwegian"), ("oc", "Occitan"), ("pa", "Panjabi"), ("pl", "Polish"),
        ("ps", "Pashto"), ("pt", "Portuguese"), ("ro", "Romanian"), ("ru", "Russian"),
        ("sa", "Sanskrit"), ("sd", "Sindhi"), ("si", "Sinhala"), ("sk", "Slovak"),
        ("sl", "Slovenian"), ("sn", "Shona"), ("so", "Somali"), ("sq", "Albanian"),
        ("sr", "Serbian"), ("su", "Sundanese"), ("sv", "Swedish"), ("sw", "Swahili"),
        ("ta", "Tamil"), ("te", "Telugu"), ("tg", "Tajik"), ("th", "Thai"),
        ("tk", "Turkmen"), ("tl", "Tagalog"), ("tr", "Turkish"), ("tt", "Tatar"),
        ("uk", "Ukrainian"), ("ur", "Urdu"), ("uz", "Uzbek"), ("vi", "Vietnamese"),
        ("yi", "Yiddish"), ("yo", "Yoruba"), ("yue", "Cantonese"), ("zh", "Chinese"),
    ]

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Toggle Dictation:")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleDictation)
                }
            }

            Section("Language") {
                Picker("Language", selection: Bindable(controller.appState).selectedLanguage) {
                    let languages = showAllLanguages ? Self.allLanguages : Self.commonLanguages
                    ForEach(languages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }

                Toggle("Show all languages", isOn: $showAllLanguages)
                    .font(.caption)
            }

            Section("Status") {
                LabeledContent("Recording State") {
                    Text(stateDescription)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Model Loaded") {
                    Image(systemName: controller.appState.isModelLoaded ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(controller.appState.isModelLoaded ? .green : .red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var stateDescription: String {
        switch controller.appState.recordingState {
        case .idle: return "Idle"
        case .recording: return "Recording"
        case .transcribing: return "Transcribing"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - Model Settings

private struct ModelSettingsTab: View {
    let controller: DictationController
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: WhisperModelType?

    /// Use the controller's shared ModelManager — never create new instances.
    /// Creating separate instances breaks cancel/delete because download state
    /// (downloadTask, continuation) lives on the instance that started the download.
    private var modelManager: ModelManager { controller.modelManager }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Model list
                VStack(spacing: 0) {
                    ForEach(WhisperModelType.allCases) { model in
                        ModelRow(
                            model: model,
                            isActive: controller.appState.selectedModelType == model,
                            isInstalled: modelManager.isModelAvailable(model),
                            isDownloading: controller.appState.downloadingModelType == model,
                            downloadProgress: controller.appState.downloadingModelType == model
                                ? controller.appState.downloadProgress : nil,
                            downloadError: controller.appState.downloadingModelType == model
                                ? controller.appState.downloadError : nil,
                            anyDownloadActive: controller.appState.isDownloading,
                            onSelect: {
                                selectModel(model)
                            },
                            onDownload: {
                                startDownload(model)
                            },
                            onCancel: {
                                cancelDownload()
                            },
                            onRetry: {
                                controller.appState.downloadError = nil
                                startDownload(model)
                            },
                            onDelete: {
                                modelToDelete = model
                                showDeleteConfirmation = true
                            }
                        )

                        if model != WhisperModelType.allCases.last {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()

                Text("Click an installed model to use it for transcription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .alert("Delete \"\(modelToDelete?.displayName ?? "")\" model?",
               isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                modelToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let model = modelToDelete {
                    deleteModel(model)
                }
                modelToDelete = nil
            }
        } message: {
            if let model = modelToDelete {
                Text("This will free up \(model.sizeDescription) of disk space. You can re-download it anytime.")
            }
        }
    }

    private func selectModel(_ model: WhisperModelType) {
        guard modelManager.isModelAvailable(model) else { return }
        controller.appState.selectedModelType = model
        controller.appState.isModelLoaded = false
        Task {
            try? await controller.ensureModelLoaded()
        }
    }

    private func startDownload(_ model: WhisperModelType) {
        guard !controller.appState.isDownloading else { return }
        controller.appState.downloadingModelType = model
        controller.appState.downloadProgress = 0
        controller.appState.downloadError = nil

        let mgr = controller.modelManager
        Task {
            do {
                try await mgr.downloadModel(model) { fraction in
                    Task { @MainActor in
                        controller.appState.downloadProgress = fraction
                    }
                }
                await MainActor.run {
                    controller.appState.downloadingModelType = nil
                    controller.appState.downloadProgress = nil
                    controller.refreshStatus()
                }
            } catch is CancellationError {
                await MainActor.run {
                    controller.appState.downloadingModelType = nil
                    controller.appState.downloadProgress = nil
                    controller.appState.downloadError = nil
                }
            } catch {
                await MainActor.run {
                    controller.appState.downloadProgress = nil
                    controller.appState.downloadError = error.localizedDescription
                }
            }
        }
    }

    private func cancelDownload() {
        controller.modelManager.cancelDownload()
        controller.appState.downloadingModelType = nil
        controller.appState.downloadProgress = nil
        controller.appState.downloadError = nil
    }

    private func deleteModel(_ model: WhisperModelType) {
        do {
            try controller.modelManager.deleteModel(model)
            controller.refreshStatus()
        } catch {
            controller.appState.lastError = error.localizedDescription
        }
    }
}

// MARK: - Model Row

private struct ModelRow: View {
    let model: WhisperModelType
    let isActive: Bool
    let isInstalled: Bool
    let isDownloading: Bool
    let downloadProgress: Double?
    let downloadError: String?
    let anyDownloadActive: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onDelete: () -> Void

    private var isSelectable: Bool { isInstalled && !isActive }
    private var showDownloadButton: Bool { !isInstalled && !isDownloading && downloadError == nil }
    private var showRetryButton: Bool { downloadError != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Radio button
                radioButton
                    .frame(width: 18, height: 18)

                // Model info
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.system(size: 13, weight: .medium))

                    Text(model.sizeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                Spacer()

                // Actions — ORDER MATTERS: error (Retry) must be checked before
                // downloading (Cancel), because downloadingModelType stays non-nil
                // on error so isDownloading is still true.
                if isActive {
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if isInstalled {
                    Button("Delete", action: onDelete)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                } else if showRetryButton {
                    // Error state — show Retry (checked BEFORE isDownloading)
                    Button("Retry", action: onRetry)
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else if isDownloading {
                    HStack(spacing: 8) {
                        if let progress = downloadProgress {
                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Cancel", action: onCancel)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                } else if showDownloadButton {
                    Button("Download", action: onDownload)
                        .font(.caption)
                        .disabled(anyDownloadActive)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelectable { onSelect() }
            }
            .background(isActive ? Color.green.opacity(0.06) : Color.clear)

            // Download progress bar
            if isDownloading, let progress = downloadProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .tint(.blue)

                    let downloaded = Int64(progress * Double(model.approximateSize))
                    let formatter = ByteCountFormatter()
                    Text("\(formatter.string(fromByteCount: downloaded)) of \(model.sizeDescription)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 46)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
            }

            // Error message
            if let error = downloadError {
                Text("Download failed — \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 46)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private var radioButton: some View {
        if isInstalled || isActive {
            Circle()
                .strokeBorder(isActive ? .green : .secondary.opacity(0.5), lineWidth: 2)
                .background(
                    Circle()
                        .fill(isActive ? .green : .clear)
                        .padding(4)
                )
        } else {
            Circle()
                .strokeBorder(.secondary.opacity(0.2), lineWidth: 2)
        }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

```bash
swift build
```

Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/WhisprLocalUI/SettingsView.swift
git commit -m "feat: redesign SettingsView with multi-model list, download progress, delete support"
```

---

## Task 10: SetupView — Redesign and Remove Duplicate Polling

**Files:**
- Modify: `Sources/WhisprLocalUI/SetupView.swift`

- [ ] **Step 1: Rewrite SetupView**

Replace the full `SetupView.swift`:

```swift
import SwiftUI
import WhisprLocalCore

public struct SetupView: View {
    let controller: DictationController
    @Binding var selectedTab: Int
    private let permissionManager = PermissionManager()

    public init(controller: DictationController, selectedTab: Binding<Int>) {
        self.controller = controller
        self._selectedTab = selectedTab
    }

    /// Setup checks if ANY model is installed, not just the selected one.
    /// Uses controller.modelManager — never create new instances.
    private var anyModelInstalled: Bool {
        !controller.modelManager.installedModels().isEmpty
    }

    private var allComplete: Bool {
        controller.appState.hasMicrophonePermission
            && controller.appState.hasAccessibilityPermission
            && anyModelInstalled
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Permission & model rows
                VStack(spacing: 0) {
                    // Microphone
                    SetupRow(
                        icon: "🎙",
                        title: "Microphone",
                        subtitle: controller.appState.hasMicrophonePermission
                            ? nil : "Required to capture audio",
                        isGranted: controller.appState.hasMicrophonePermission,
                        action: {
                            Task {
                                let granted = await permissionManager.requestMicrophonePermission()
                                await MainActor.run {
                                    controller.appState.hasMicrophonePermission = granted
                                }
                            }
                        },
                        actionLabel: "Grant"
                    )

                    Divider().padding(.leading, 56)

                    // Accessibility
                    SetupRow(
                        icon: "⌨️",
                        title: "Accessibility",
                        subtitle: controller.appState.hasAccessibilityPermission
                            ? nil : "Required to paste transcribed text",
                        isGranted: controller.appState.hasAccessibilityPermission,
                        action: {
                            permissionManager.requestAccessibilityPermission()
                        },
                        actionLabel: "Open Settings"
                    )

                    Divider().padding(.leading, 56)

                    // Model
                    SetupRow(
                        icon: "🧠",
                        title: "Whisper Model",
                        subtitle: anyModelInstalled
                            ? nil : "Download a model to start transcribing",
                        isGranted: anyModelInstalled,
                        action: { selectedTab = 1 },
                        actionLabel: "Go to Models"
                    )
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

                // All set banner
                if allComplete {
                    HStack {
                        Spacer()
                        Text("All set — press ⌥D anywhere to start dictating")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.green)
                        Spacer()
                    }
                    .padding(12)
                    .background(.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Setup Row

private struct SetupRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let isGranted: Bool
    let action: (() -> Void)?
    let actionLabel: String

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
                .frame(width: 28, height: 28)
                .background(isGranted ? Color.green.opacity(0.1) : Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else if let action {
                Button(actionLabel, action: action)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
```

Key changes:
- Removed duplicate `.task` polling (relies on AppDelegate's 2s timer)
- Setup checks `anyModelInstalled` (any model, not just selected)
- Clean row-based layout matching the mockup
- "All set" banner when complete

- [ ] **Step 2: Build to verify compilation**

```bash
swift build
```

Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add Sources/WhisprLocalUI/SetupView.swift
git commit -m "feat: redesign SetupView, remove duplicate polling, check any model installed"
```

---

## Task 11: CI/CD — GitHub Actions Workflows

**Files:**
- Create: `.github/workflows/build.yml`
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create directories**

```bash
mkdir -p .github/workflows
```

- [ ] **Step 2: Create build & test workflow**

Create `.github/workflows/build.yml`:

```yaml
name: Build & Test

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

      - name: Build
        run: swift build

      - name: Test
        run: swift test
```

- [ ] **Step 3: Create release workflow**

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

      - name: Extract version from tag
        id: version
        run: echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"

      - name: Update version in Info.plist
        run: |
          /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${{ steps.version.outputs.version }}" Resources/Info.plist
          COMMIT_COUNT=$(git rev-list --count HEAD)
          /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $COMMIT_COUNT" Resources/Info.plist

      - name: Build release
        run: swift build -c release

      - name: Create app bundle
        run: ./scripts/build-app.sh release

      - name: Create DMG
        run: ./scripts/create-dmg.sh

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "$GITHUB_REF_NAME" \
            --title "WhisprLocal ${{ steps.version.outputs.version }}" \
            --generate-notes \
            build/WhisprLocal.dmg
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/build.yml .github/workflows/release.yml
git commit -m "feat: add GitHub Actions for CI build/test and tag-based DMG releases"
```

---

## Task 12: Final Build Verification

**Files:** None (verification only)

- [ ] **Step 1: Full build**

```bash
swift build
```

Expected: Build succeeded with no errors or warnings related to our changes.

- [ ] **Step 2: Run all tests**

```bash
xcode-select -s /Applications/Xcode.app/Contents/Developer && swift test
```

Expected: All tests pass including new AppState download tests.

- [ ] **Step 3: Build app bundle**

```bash
./scripts/build-app.sh debug
```

Expected: Build complete, app bundle at `build/WhisprLocal.app` with icon.

- [ ] **Step 4: Verify app icon**

```bash
ls -la build/WhisprLocal.app/Contents/Resources/AppIcon.icns
/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" build/WhisprLocal.app/Contents/Info.plist
```

Expected: Icon file exists, PlistBuddy prints "AppIcon"

- [ ] **Step 5: Commit all remaining changes (if any)**

```bash
git status
# If clean: no commit needed
# If changes: stage and commit with appropriate message
```

---

## Task Summary

| Task | Area | Description |
|------|------|-------------|
| 1 | Icon | Convert PNG → .icns, wire into Info.plist and build script |
| 2 | Core | Add idle → error transition to RecordingState (needed by Tasks 5, 6) |
| 3 | Core | Add download state properties to AppState |
| 4 | Core | Add `resetEngine()` to AudioRecorder |
| 5 | Core | Fix DictationController state ordering, make modelManager public, add sleep support |
| 6 | App | Sleep/wake handlers (with timing guard) and single-instance check in AppDelegate |
| 7 | Core | ModelManager robustness — concurrent guard, orphan cleanup |
| 8 | UI | Redesign MenuBarView — scroll, copy, errors |
| 9 | UI | Redesign SettingsView — multi-model list, uses controller.modelManager, condition ordering fixed |
| 10 | UI | Redesign SetupView — tab binding for "Go to Models", uses controller.modelManager |
| 11 | CI/CD | GitHub Actions for build/test and tagged releases |
| 12 | Verify | Full build, test, and bundle verification |

## Review Fixes Applied

| # | Issue | Fix |
|---|-------|-----|
| 1 | ModelManager singleton — views creating new instances, cancel broken | Made `modelManager` public on DictationController. All views use `controller.modelManager`. |
| 2 | Missing idle → error transition | Added to RecordingState as new Task 2. |
| 3 | Download error shows Cancel instead of Retry | Reordered conditions: `showRetryButton` checked before `isDownloading`. |
| 4 | SetupView "Go to Models" button dead | Added `@Binding var selectedTab: Int`, action sets it to 1. |
| 5 | Sleep/wake timing — error during transcription | Added guard `!controller.appState.recordingState.isTranscribing` in handleWake. |
| 6 | anyModelInstalled creates new ModelManager per render | Uses `controller.modelManager.installedModels()`. |
