import XCTest
@testable import WhisprLocalCore

final class AppStateTests: XCTestCase {

    func testInitialState() {
        let state = AppState()
        XCTAssertEqual(state.recordingState, .idle)
        XCTAssertEqual(state.selectedModelType, .base)
        XCTAssertFalse(state.isModelLoaded)
        XCTAssertEqual(state.lastTranscription, "")
        XCTAssertNil(state.lastError)
        XCTAssertFalse(state.hasMicrophonePermission)
        XCTAssertFalse(state.hasAccessibilityPermission)
        XCTAssertFalse(state.isModelAvailable)
        XCTAssertFalse(state.isSetupComplete)
    }

    func testSetupCompleteRequiresAllThreeConditions() {
        let state = AppState()

        state.hasMicrophonePermission = true
        XCTAssertFalse(state.isSetupComplete)

        state.hasAccessibilityPermission = true
        XCTAssertFalse(state.isSetupComplete)

        state.isModelAvailable = true
        XCTAssertTrue(state.isSetupComplete)
    }

    func testIdleToRecordingTransition() {
        let state = AppState()
        let result = state.transition(to: .recording)
        XCTAssertTrue(result)
        XCTAssertEqual(state.recordingState, .recording)
    }

    func testIdleToTranscribingTransitionFails() {
        let state = AppState()
        let result = state.transition(to: .transcribing)
        XCTAssertFalse(result)
        XCTAssertEqual(state.recordingState, .idle)
    }

    func testRecordingToTranscribingTransition() {
        let state = AppState()
        state.transition(to: .recording)
        let result = state.transition(to: .transcribing)
        XCTAssertTrue(result)
        XCTAssertEqual(state.recordingState, .transcribing)
    }

    func testTranscribingToIdleTransition() {
        let state = AppState()
        state.transition(to: .recording)
        state.transition(to: .transcribing)
        let result = state.transition(to: .idle)
        XCTAssertTrue(result)
        XCTAssertEqual(state.recordingState, .idle)
    }

    func testErrorTransitionSetsLastError() {
        let state = AppState()
        state.transition(to: .recording)
        state.transition(to: .error("test error"))
        XCTAssertTrue(state.recordingState.isError)
        XCTAssertEqual(state.lastError, "test error")
    }

    func testClearErrorResetsToIdle() {
        let state = AppState()
        state.transition(to: .recording)
        state.transition(to: .error("test error"))
        state.clearError()
        XCTAssertEqual(state.recordingState, .idle)
        XCTAssertNil(state.lastError)
    }

    func testRecordingToIdleCancel() {
        let state = AppState()
        state.transition(to: .recording)
        let result = state.transition(to: .idle)
        XCTAssertTrue(result)
        XCTAssertEqual(state.recordingState, .idle)
    }
}
