# WhisprLocal v2 — Full Rehaul Design Spec

**Date:** 2026-04-04
**Status:** Approved
**Scope:** App icon, CI/CD, sleep/wake audio fix, frontend redesign, model download robustness, UX improvements

---

## 1. App Icon

### Problem
No app icon exists. No `.icns` file, no `CFBundleIconFile` in Info.plist, no asset catalog. App appears as generic white icon in Finder/Launchpad.

### Solution
Convert the user-provided PNG (retro CRT pixel-art style, green phosphor glow) into a proper macOS `.icns` file.

### Implementation
- Source: `/Users/harshsh/.claude/image-cache/8e0e3102-d485-4528-8f92-71b341f7eb59/1.png`
- Generate all required sizes: 16x16, 32x32, 128x128, 256x256, 512x512, 1024x1024 (plus @2x variants)
- Use `sips` for resizing, `iconutil` to create `.icns` from `.iconset` directory
- Output: `Resources/AppIcon.icns`
- Add `CFBundleIconFile` = `AppIcon` to `Resources/Info.plist`
- Update `scripts/build-app.sh` to copy `.icns` into `Contents/Resources/` in the app bundle

### Files Changed
- `Resources/AppIcon.icns` (new)
- `Resources/Info.plist` (add CFBundleIconFile)
- `scripts/build-app.sh` (copy icon into bundle)

---

## 2. CI/CD — Tag-Based GitHub Releases

### Problem
No GitHub Actions workflows exist. DMG builds are manual. No automated testing on push.

### Solution
Two GitHub Actions workflows:
1. **Build & Test** — runs on every push to `main` and on PRs
2. **Release** — runs on tag push (`v*`), builds DMG, creates GitHub Release

### Workflow 1: Build & Test (`.github/workflows/build.yml`)
- **Trigger:** push to `main`, pull requests to `main`
- **Runner:** `macos-14` (Apple Silicon)
- **Steps:**
  1. Checkout
  2. Select Xcode (latest stable)
  3. `swift build`
  4. `swift test` (requires Xcode, not just CLT)
- **Purpose:** Catch build/test breakage early

### Workflow 2: Release (`.github/workflows/release.yml`)
- **Trigger:** push tags matching `v*` (e.g., `v1.1.0`)
- **Runner:** `macos-14`
- **Steps:**
  1. Checkout
  2. Select Xcode
  3. `swift build -c release`
  4. `./scripts/build-app.sh release`
  5. `./scripts/create-dmg.sh`
  6. Create GitHub Release via `gh release create` with tag name as title
  7. Upload `build/WhisprLocal.dmg` as release asset
- **Version:** Extracted from git tag (strip `v` prefix), injected into Info.plist before build using `sed` or `plutil`

### Version Management
- `CFBundleShortVersionString`: derived from git tag (e.g., `v1.2.0` → `1.2.0`)
- `CFBundleVersion`: git commit count or tag-derived build number
- Release workflow updates Info.plist before building so the DMG has the correct version baked in

### Files Changed
- `.github/workflows/build.yml` (new)
- `.github/workflows/release.yml` (new)

---

## 3. Sleep/Wake Audio Bug Fix

### Problem
After Mac sleep or extended idle, pressing Option+D starts "recording" but:
- No mic indicator dot appears (AVAudioEngine is in zombie state)
- Pressing Option+D again to stop produces error "No audio data"
- App must be restarted to recover

### Root Causes
1. **AVAudioEngine created once, never reset after sleep** (`AudioRecorder.swift:23`)
2. **No sleep/wake notification listeners** in AppDelegate
3. **State set before validation** — `AppState` transitions to `.recording` before `audioRecorder.startRecording()` succeeds (`DictationController.swift:51`)
4. **Wrong state checked in stopRecording** — checks `appState.recordingState` instead of `audioRecorder.isRecording` (`DictationController.swift:62`)

### Solution
Extend existing code with sleep/wake awareness. Do NOT rewrite working code.

### Changes to AppDelegate (`AppDelegate.swift`)
**Add** sleep/wake notification observers in `applicationDidFinishLaunching`:
```
NSWorkspace.shared.notificationCenter.addObserver for:
  - screensDidSleepNotification → handleSleep()
  - screensDidWakeNotification → handleWake()
```

**handleSleep():**
- If currently recording: call `controller.stopRecording()` to auto-stop and transcribe partial audio, then set `controller.wasInterruptedBySleep = true` (new Bool property on DictationController, default false)
- If not recording: no-op

**handleWake():**
- Call `controller.resetAudioEngine()` which delegates to `audioRecorder.resetEngine()` (new method) to recreate AVAudioEngine
- If `controller.wasInterruptedBySleep`: transition to `.error("Recording was interrupted because the system went to sleep. Partial transcription was saved.")`
- Set `controller.wasInterruptedBySleep = false`

### Changes to AudioRecorder (`AudioRecorder.swift`)
**Add** `resetEngine()` method:
- Stop and remove tap from current engine
- Create new `AVAudioEngine()` instance (replace the existing one)
- Reset `isRecording` to false
- This method is called on wake to ensure a clean audio engine

**Do NOT change:**
- `startRecording()` flow (works correctly when engine is healthy)
- `stopRecording()` flow
- Audio format/converter setup
- Buffer/samples collection logic

### Changes to DictationController (`DictationController.swift`)
**Fix `startRecording()`** (line 50-58):
- Move `appState.transition(to: .recording)` to AFTER `audioRecorder.startRecording()` succeeds
- If `startRecording()` throws, state stays `.idle` (never entered `.recording`)

**Fix `stopRecording()`** (line 61-74):
- Add consistency check: verify both `appState.recordingState.isRecording` AND `audioRecorder.isRecording` before proceeding
- If out of sync: reset both to idle, log warning

### Files Changed
- `Sources/WhisprLocal/AppDelegate.swift` (add sleep/wake handlers)
- `Sources/WhisprLocalCore/Services/AudioRecorder.swift` (add `resetEngine()` method)
- `Sources/WhisprLocalCore/DictationController.swift` (fix state ordering, add sync check)

### What We Do NOT Touch
- PermissionManager — works correctly
- Permission checking/granting flow — works correctly
- AppDelegate polling mechanism — works correctly
- WhisperTranscriber actor — works correctly
- TextInjector — works correctly
- HotkeyManager — works correctly

---

## 4. Frontend Redesign

### Design Principles
- Native SwiftUI, macOS-idiomatic (System Settings style)
- No custom chrome, no electron feel
- Extend, don't rewrite — keep existing @Observable pattern, DictationController as view model

### 4.1 Menu Bar Popover (`MenuBarView.swift`)

**Current issues:**
- Fixed 280px width, no height constraint
- `.lineLimit(3)` truncates long transcriptions
- No scroll for overflow
- No copy button
- Errors silently swallowed (not shown in UI)

**Redesign:**
- Width: **320px**
- Max height with ScrollView wrapping entire content
- Padding: 16px

**States:**

**Idle/Ready:**
```
┌──────────────────────────────────┐
│ ● Ready          Base model loaded│
│──────────────────────────────────│
│ Last Transcription        ⧉ Copy │
│ ┌──────────────────────────────┐ │
│ │ Full text here, scrollable   │ │
│ │ if needed, max-height 120px  │ │
│ └──────────────────────────────┘ │
│──────────────────────────────────│
│ Shortcut                     ⌥D │
│──────────────────────────────────│
│ Settings...                 Quit │
└──────────────────────────────────┘
```

**Recording:**
```
┌──────────────────────────────────┐
│ 🔴 Recording...   Press ⌥D to stop│
└──────────────────────────────────┘
```
- Red pulsing dot + text + hint. No progress bar.

**Transcribing:**
```
┌──────────────────────────────────┐
│ 🔵 Transcribing...   Just a moment│
└──────────────────────────────────┘
```

**Error:**
```
┌──────────────────────────────────┐
│ ⚠ Recording Interrupted          │
│ ┌──────────────────────────────┐ │
│ │ Error message here           │ │
│ └──────────────────────────────┘ │
│ [Dismiss]                        │
└──────────────────────────────────┘
```

**Key changes:**
- Transcription area: Remove `.lineLimit(3)`. Add ScrollView with `.frame(maxHeight: 120)`. Background container with rounded corners. `.textSelection(.enabled)`.
- Copy button: Next to "Last Transcription" label. Copies `appState.lastTranscription` to `NSPasteboard`. Brief "Copied!" feedback.
- Error display: When `appState.recordingState` is `.error(message)`, show warning banner with message and Dismiss button.
- Setup prompt: Keep existing SetupPromptSection but style to match new design.

### 4.2 Settings Window (`SettingsView.swift`)

**Current issues:**
- Fixed 450×320 frame — too small
- No scroll in tabs
- Download errors not displayed

**Redesign:**
- Frame: **520×440** (wider, taller)
- Each tab gets a ScrollView wrapper for safety
- Consistent grouped-row style across all tabs

**General Tab:**
- Shortcut section: grouped row with KeyboardShortcuts.Recorder
- Language section: grouped row with Picker + "Show all languages" toggle
- Status section: grouped row showing state + model loaded indicator

**Models Tab (major redesign):**
All 4 models shown in a single grouped list. Each row has a radio button for selection.

Row states (5 total):
1. **Active** — green radio filled, green background tint, "Active" label, no delete
2. **Installed** — empty radio, clickable to activate, Delete button
3. **Not installed** — dimmed, radio disabled, Download button
4. **Downloading** — inline progress bar (3px height, blue), percentage, MB progress, Cancel button. Progress bar and details indented under row, aligned with model name.
5. **Failed** — red error text indented under row, Retry button replaces Download

Active model dropdown removed — replaced by radio selection in the list. Only installed models are selectable.

Footer hint: "Click an installed model to use it for transcription."

**Setup Tab:**
Three rows in grouped list, one per requirement:
1. 🎙 Microphone — "Grant" button or ✓
2. ⌨️ Accessibility — "Open Settings" button or ✓
3. 🧠 Whisper Model — "Go to Models" button or ✓

Model row logic: shows ✓ if ANY model is installed (not tied to specific model). Setup doesn't show download progress — that's the Models tab's job.

When all three are ✓: green banner "All set — press ⌥D anywhere to start dictating"

Mixed states supported: each row independently shows its status.

**Delete confirmation dialog:**
Native macOS `.alert` style:
- Title: `Delete "Base" model?`
- Message: `This will free up 142 MB of disk space. You can re-download it anytime.`
- Buttons: Cancel (default), Delete (destructive, red)

### 4.3 SetupView Polling Fix
**Current:** SetupView polls every 2s AND AppDelegate polls every 2s = double polling.
**Fix:** Remove polling from SetupView. Rely solely on AppDelegate's existing 2s polling which updates AppState. Views react automatically via @Observable.

### Files Changed
- `Sources/WhisprLocalUI/MenuBarView.swift` (redesign)
- `Sources/WhisprLocalUI/SettingsView.swift` (redesign)
- `Sources/WhisprLocalUI/SetupView.swift` (redesign + remove polling)

---

## 5. Model Download Robustness

### Current Issues
- Download errors silently stored in `lastError` but never shown in UI
- No retry mechanism
- Orphaned temp files on failure/cancel
- No concurrent download prevention
- File size validation has silent failure path

### Solution

**Error Display:**
- Per-model error state tracked in AppState (not just global `lastError`)
- Error text shown inline under the failed model row
- Retry button replaces Download button on failure

**AppState Changes:**
Add new properties:
```swift
public var downloadError: String?           // Error message for last download attempt
public var downloadingModelType: WhisperModelType?  // Which model is currently downloading
```

Replace single `downloadProgress: Double?` with model-aware state so UI knows which model is downloading.

**Retry:**
- On failure: clean up partial/temp files, show error, show Retry button
- Retry = same as fresh download (no resume, just clean start)

**Orphaned Temp File Cleanup:**
- On app launch: scan `FileManager.temporaryDirectory` for `*.bin` files matching UUID pattern
- Delete any found (these are leftovers from failed downloads)
- Add to `ModelManager.cleanupOrphanedFiles()`, called from AppDelegate on launch

**Concurrent Download Prevention:**
- `ModelManager.downloadModel()` checks `appState.isDownloading` before starting
- If already downloading: return early or throw `ModelManagerError.downloadInProgress`
- UI: Download buttons disabled on other models while one is downloading

**File Validation Improvement:**
- Make the catch block in size validation explicit: if `attributesOfItem` throws, treat as invalid
- Log the error for debugging

**Cancel Cleanup:**
- On cancel: ensure temp file is removed (currently orphaned)
- Reset `downloadProgress`, `downloadingModelType`, `downloadError` to nil

### Model Deletion
Add `deleteModel(_ modelType:)` public method to ModelManager:
- Verify model is not the active model (caller responsibility, enforced by UI)
- Delete file at `modelPath(for: modelType)`
- Update `appState.isModelAvailable` via refresh
- Show confirmation dialog before deletion (UI-side)

### Files Changed
- `Sources/WhisprLocalCore/Models/AppState.swift` (add download state properties)
- `Sources/WhisprLocalCore/Services/ModelManager.swift` (cleanup, concurrent prevention, cancel cleanup, delete method)
- `Sources/WhisprLocalUI/SettingsView.swift` (model list with all 5 states, delete confirmation)

---

## 6. Additional Features

### 6.1 Copy Last Transcription
- Button in MenuBarView next to "Last Transcription" label
- Copies `appState.lastTranscription` to `NSPasteboard.general`
- Brief visual feedback: button text changes to "Copied!" for 1.5 seconds, then reverts

### 6.2 Single-Instance Check
- In AppDelegate `applicationDidFinishLaunching`: check `NSRunningApplication.runningApplications(withBundleIdentifier:)`
- If another instance found: activate it via `NSRunningApplication.activate()`, then `NSApp.terminate(nil)` self
- Ensures no duplicate processes

---

## Summary of All Files Changed

### New Files
- `Resources/AppIcon.icns`
- `.github/workflows/build.yml`
- `.github/workflows/release.yml`

### Modified Files
- `Resources/Info.plist` (add CFBundleIconFile)
- `scripts/build-app.sh` (copy icon into bundle)
- `Sources/WhisprLocal/AppDelegate.swift` (sleep/wake handlers, single-instance check, temp cleanup)
- `Sources/WhisprLocalCore/Services/AudioRecorder.swift` (add resetEngine method)
- `Sources/WhisprLocalCore/DictationController.swift` (fix state ordering, sync check)
- `Sources/WhisprLocalCore/Models/AppState.swift` (add download state properties)
- `Sources/WhisprLocalCore/Services/ModelManager.swift` (cleanup, concurrent prevention, delete, cancel fix)
- `Sources/WhisprLocalUI/MenuBarView.swift` (full redesign)
- `Sources/WhisprLocalUI/SettingsView.swift` (full redesign)
- `Sources/WhisprLocalUI/SetupView.swift` (redesign, remove polling)

### Untouched (Working Correctly)
- `Sources/WhisprLocalCore/Services/PermissionManager.swift`
- `Sources/WhisprLocalCore/Services/WhisperTranscriber.swift`
- `Sources/WhisprLocalCore/Services/TextInjector.swift`
- `Sources/WhisprLocalCore/Services/HotkeyManager.swift`
- `Sources/WhisprLocalCore/Models/RecordingState.swift`
- `Sources/WhisprLocalCore/Models/WhisperModelType.swift`
- `Package.swift`
- All test files (existing tests preserved, new tests added for new functionality)
