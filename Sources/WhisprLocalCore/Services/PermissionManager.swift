import AVFoundation
import Cocoa

/// Manages checking and requesting system permissions (microphone + accessibility).
public final class PermissionManager: Sendable {
    public init() {}

    // MARK: - Accessibility

    /// Check if accessibility permission is granted (required for CGEvent text injection).
    public func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility permission via System Settings.
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Microphone

    /// Check the current microphone authorization status.
    public func checkMicrophonePermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Request microphone permission. Calls completion on main thread.
    public func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Open System Settings to the relevant privacy pane.
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
