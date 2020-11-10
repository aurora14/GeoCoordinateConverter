import XCTest
@testable import GeoCoordinateConverter

final class GeoCoordinateConverterTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(GeoCoordinateConverter().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
