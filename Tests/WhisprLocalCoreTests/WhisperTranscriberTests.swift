import XCTest
@testable import WhisprLocalCore

final class WhisperTranscriberTests: XCTestCase {

    func testInitialStateHasNoModelLoaded() async {
        let transcriber = WhisperTranscriber()
        let loaded = await transcriber.isModelLoaded
        XCTAssertFalse(loaded)
    }

    func testTranscribeThrowsWhenNoModelLoaded() async {
        let transcriber = WhisperTranscriber()
        do {
            _ = try await transcriber.transcribe(samples: [1.0, 2.0, 3.0])
            XCTFail("Expected TranscriberError.modelNotLoaded")
        } catch is TranscriberError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLoadModelFailsWithInvalidPath() async {
        let transcriber = WhisperTranscriber()
        do {
            try await transcriber.loadModel(path: "/nonexistent/path/model.bin")
            XCTFail("Expected TranscriberError.modelLoadFailed")
        } catch let error as TranscriberError {
            if case .modelLoadFailed = error {
                // expected
            } else {
                XCTFail("Expected modelLoadFailed, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnloadModelWhenNoneLoadedIsSafe() async {
        let transcriber = WhisperTranscriber()
        await transcriber.unloadModel()
        let loaded = await transcriber.isModelLoaded
        XCTAssertFalse(loaded)
    }
}
