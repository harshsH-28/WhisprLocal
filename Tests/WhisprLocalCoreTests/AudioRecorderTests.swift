import XCTest
@testable import WhisprLocalCore

final class AudioRecorderTests: XCTestCase {

    func testInitialStateIsNotRecording() {
        let recorder = AudioRecorder()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(recorder.currentDuration, 0)
    }

    func testStopRecordingThrowsWhenNotRecording() {
        let recorder = AudioRecorder()
        XCTAssertThrowsError(try recorder.stopRecording()) { error in
            XCTAssertTrue(error is AudioRecorderError)
        }
    }

    func testCancelRecordingIsSafeWhenNotRecording() {
        let recorder = AudioRecorder()
        recorder.cancelRecording()
        XCTAssertFalse(recorder.isRecording)
    }

    func testDoubleStartThrowsAlreadyRecording() {
        let recorder = AudioRecorder()
        do {
            try recorder.startRecording()
            // If start succeeded, verify double-start throws
            XCTAssertThrowsError(try recorder.startRecording()) { error in
                guard let recorderError = error as? AudioRecorderError else {
                    XCTFail("Expected AudioRecorderError")
                    return
                }
                if case .alreadyRecording = recorderError {
                    // expected
                } else {
                    XCTFail("Expected .alreadyRecording, got \(recorderError)")
                }
            }
            recorder.cancelRecording()
        } catch {
            // Expected on machines without mic — skip
        }
    }
}
