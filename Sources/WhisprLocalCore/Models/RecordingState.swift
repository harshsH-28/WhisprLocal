import Foundation

/// State machine for the dictation recording lifecycle.
public enum RecordingState: Equatable, Sendable {
    case idle
    case recording
    case transcribing
    case error(String)

    public var isIdle: Bool { self == .idle }
    public var isRecording: Bool { self == .recording }
    public var isTranscribing: Bool { self == .transcribing }

    public var isError: Bool {
        if case .error = self { return true }
        return false
    }

    /// Valid transitions for the state machine.
    public func canTransition(to next: RecordingState) -> Bool {
        switch (self, next) {
        case (.idle, .recording):
            return true
        case (.recording, .transcribing):
            return true
        case (.recording, .idle):         // cancelled
            return true
        case (.transcribing, .idle):      // completed
            return true
        case (.transcribing, .error):     // transcription failed
            return true
        case (.recording, .error):        // recording failed
            return true
        case (.error, .idle):             // reset after error
            return true
        default:
            return false
        }
    }
}
