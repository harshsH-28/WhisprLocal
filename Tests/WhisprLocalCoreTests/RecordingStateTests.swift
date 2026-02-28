import XCTest
@testable import WhisprLocalCore

final class RecordingStateTests: XCTestCase {

    // MARK: - State Properties

    func testIdleStateProperties() {
        let state = RecordingState.idle
        XCTAssertTrue(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isTranscribing)
        XCTAssertFalse(state.isError)
    }

    func testRecordingStateProperties() {
        let state = RecordingState.recording
        XCTAssertFalse(state.isIdle)
        XCTAssertTrue(state.isRecording)
        XCTAssertFalse(state.isTranscribing)
        XCTAssertFalse(state.isError)
    }

    func testTranscribingStateProperties() {
        let state = RecordingState.transcribing
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertTrue(state.isTranscribing)
        XCTAssertFalse(state.isError)
    }

    func testErrorStateProperties() {
        let state = RecordingState.error("test")
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isTranscribing)
        XCTAssertTrue(state.isError)
    }

    // MARK: - Valid Transitions

    func testIdleToRecording() {
        XCTAssertTrue(RecordingState.idle.canTransition(to: .recording))
    }

    func testRecordingToTranscribing() {
        XCTAssertTrue(RecordingState.recording.canTransition(to: .transcribing))
    }

    func testRecordingToIdle() {
        XCTAssertTrue(RecordingState.recording.canTransition(to: .idle))
    }

    func testRecordingToError() {
        XCTAssertTrue(RecordingState.recording.canTransition(to: .error("fail")))
    }

    func testTranscribingToIdle() {
        XCTAssertTrue(RecordingState.transcribing.canTransition(to: .idle))
    }

    func testTranscribingToError() {
        XCTAssertTrue(RecordingState.transcribing.canTransition(to: .error("fail")))
    }

    func testErrorToIdle() {
        XCTAssertTrue(RecordingState.error("fail").canTransition(to: .idle))
    }

    // MARK: - Invalid Transitions

    func testIdleToTranscribingInvalid() {
        XCTAssertFalse(RecordingState.idle.canTransition(to: .transcribing))
    }

    func testIdleToIdleInvalid() {
        XCTAssertFalse(RecordingState.idle.canTransition(to: .idle))
    }

    func testTranscribingToRecordingInvalid() {
        XCTAssertFalse(RecordingState.transcribing.canTransition(to: .recording))
    }

    func testErrorToRecordingInvalid() {
        XCTAssertFalse(RecordingState.error("fail").canTransition(to: .recording))
    }
}
