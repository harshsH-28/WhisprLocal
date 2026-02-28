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

    /// Model download progress (nil = not downloading, 0.0–1.0 = in progress).
    public var downloadProgress: Double?

    /// Whether a model download is currently in progress.
    public var isDownloading: Bool { downloadProgress != nil }

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
