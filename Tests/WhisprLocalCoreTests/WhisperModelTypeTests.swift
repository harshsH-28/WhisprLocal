import XCTest
@testable import WhisprLocalCore

final class WhisperModelTypeTests: XCTestCase {

    func testAllCasesExist() {
        XCTAssertEqual(WhisperModelType.allCases.count, 4)
        XCTAssertTrue(WhisperModelType.allCases.contains(.tiny))
        XCTAssertTrue(WhisperModelType.allCases.contains(.base))
        XCTAssertTrue(WhisperModelType.allCases.contains(.small))
        XCTAssertTrue(WhisperModelType.allCases.contains(.medium))
    }

    func testFileNames() {
        XCTAssertEqual(WhisperModelType.tiny.fileName, "ggml-tiny.bin")
        XCTAssertEqual(WhisperModelType.base.fileName, "ggml-base.bin")
        XCTAssertEqual(WhisperModelType.small.fileName, "ggml-small.bin")
        XCTAssertEqual(WhisperModelType.medium.fileName, "ggml-medium.bin")
    }

    func testDisplayNames() {
        XCTAssertEqual(WhisperModelType.tiny.displayName, "Tiny")
        XCTAssertEqual(WhisperModelType.base.displayName, "Base")
        XCTAssertEqual(WhisperModelType.small.displayName, "Small")
        XCTAssertEqual(WhisperModelType.medium.displayName, "Medium")
    }

    func testSizesInOrder() {
        XCTAssertLessThan(WhisperModelType.tiny.approximateSize, WhisperModelType.base.approximateSize)
        XCTAssertLessThan(WhisperModelType.base.approximateSize, WhisperModelType.small.approximateSize)
        XCTAssertLessThan(WhisperModelType.small.approximateSize, WhisperModelType.medium.approximateSize)
    }

    func testSizeDescriptionsNonEmpty() {
        for model in WhisperModelType.allCases {
            XCTAssertFalse(model.sizeDescription.isEmpty, "\(model) has empty size description")
        }
    }

    func testQualityDescriptionsNonEmpty() {
        for model in WhisperModelType.allCases {
            XCTAssertFalse(model.qualityDescription.isEmpty, "\(model) has empty quality description")
        }
    }

    func testRecommendedModelIsBase() {
        XCTAssertEqual(WhisperModelType.recommended, .base)
    }

    func testIDsMatchRawValues() {
        for model in WhisperModelType.allCases {
            XCTAssertEqual(model.id, model.rawValue)
        }
    }
}
