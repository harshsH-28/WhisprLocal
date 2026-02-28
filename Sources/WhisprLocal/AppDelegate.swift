import AppKit
import SwiftUI
import WhisprLocalCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DictationController()
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Refresh permissions and model status
        controller.refreshStatus()

        // Register the global hotkey
        controller.setup()

        // Prompt for accessibility permission if not already granted
        let permissionManager = PermissionManager()
        if !permissionManager.checkAccessibilityPermission() {
            permissionManager.requestAccessibilityPermission()
        }

        // Continuously poll permissions so the UI stays current
        startPermissionPolling()

        // Pre-load model in background if available
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

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        controller.cancelRecording()
    }
}
