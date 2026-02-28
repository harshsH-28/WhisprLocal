import XCTest
@testable import WhisprLocalCore

final class DictationControllerTests: XCTestCase {

    func testInitialStateIsIdle() {
        let controller = DictationController()
        XCTAssertEqual(controller.appState.recordingState, .idle)
        XCTAssertFalse(controller.appState.isModelLoaded)
    }

    func testToggleDictationFromIdleAttemptsRecording() {
        let controller = DictationController()
        controller.toggleDictation()
        // State should be either recording or error (no mic)
        let state = controller.appState.recordingState
        XCTAssertTrue(state.isRecording || state.isError)
    }

    func testCancelRecordingReturnsToIdle() {
        let controller = DictationController()
        controller.cancelRecording()
        XCTAssertEqual(controller.appState.recordingState, .idle)
    }

    func testRefreshStatusDoesNotCrash() {
        let controller = DictationController()
        controller.refreshStatus()
        // Just verify it runs and sets boolean values
        _ = controller.appState.hasMicrophonePermission
        _ = controller.appState.hasAccessibilityPermission
        _ = controller.appState.isModelAvailable
    }
}
