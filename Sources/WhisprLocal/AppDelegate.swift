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
    }
}
