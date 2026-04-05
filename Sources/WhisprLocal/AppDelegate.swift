import AppKit
import Darwin
import SwiftUI
import WhisprLocalCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DictationController()
    private var permissionTimer: Timer?
    private var lockFileDescriptor: Int32 = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Single-instance check using file lock (reliable across translocation/Gatekeeper)
        if !acquireSingleInstanceLock() {
            // Another instance holds the lock — activate it and quit
            let bundleID = Bundle.main.bundleIdentifier ?? "com.whisprlocal.app"
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                where app != NSRunningApplication.current {
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

        // Request microphone permission on launch (triggers OS dialog on first run)
        if !permissionManager.checkMicrophonePermission() {
            Task {
                let granted = await permissionManager.requestMicrophonePermission()
                await MainActor.run {
                    controller.appState.hasMicrophonePermission = granted
                }
            }
        }

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
        controller.resetAudioEngine()

        if controller.wasInterruptedBySleep {
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
        releaseSingleInstanceLock()
    }

    // MARK: - Single Instance Lock

    private func acquireSingleInstanceLock() -> Bool {
        let lockPath = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisprLocal", isDirectory: true)
            .appendingPathComponent(".instance.lock")

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: lockPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Open or create the lock file
        lockFileDescriptor = open(lockPath.path, O_CREAT | O_RDWR, 0o644)
        guard lockFileDescriptor >= 0 else { return false }

        // Try exclusive non-blocking lock — fails immediately if another process holds it
        if flock(lockFileDescriptor, LOCK_EX | LOCK_NB) != 0 {
            close(lockFileDescriptor)
            lockFileDescriptor = -1
            return false
        }

        return true
    }

    private func releaseSingleInstanceLock() {
        if lockFileDescriptor >= 0 {
            flock(lockFileDescriptor, LOCK_UN)
            close(lockFileDescriptor)
            lockFileDescriptor = -1
        }
    }
}
