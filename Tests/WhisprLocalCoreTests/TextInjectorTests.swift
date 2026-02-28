import XCTest
@testable import WhisprLocalCore

final class TextInjectorTests: XCTestCase {

    func testInjectEmptyTextThrows() async {
        let injector = TextInjector()
        do {
            try await injector.inject(text: "")
            XCTFail("Expected TextInjectorError.emptyText")
        } catch let error as TextInjectorError {
            XCTAssertEqual(error, .emptyText)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
