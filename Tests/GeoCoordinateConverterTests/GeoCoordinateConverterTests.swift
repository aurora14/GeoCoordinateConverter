import XCTest
@testable import GeoCoordinateConverter

final class GeoCoordinateConverterTests: XCTestCase {

    let converter = GeoCoordinateConverter()
    let utm = LatLongUTM()
    let mgrs = LatLongMGRS()

    let testCities: [TestLocationModel] = [
      TestLocationModel(name: "Berlin", latitude: 52.520007, longitude: 13.404954, utm: "33U 391776 5820073", mgrs: "33UUU 91776 20073"),
      TestLocationModel(name: "London", latitude: 51.507351, longitude: -0.127758, utm: "30U 699319 5710158", mgrs: "30UXC 99319 10158"),
      TestLocationModel(name: "New York", latitude: 40.712784, longitude: -74.005941, utm: "18T 583964 4507349", mgrs: "18TWL 83964 07349"),
      TestLocationModel(name: "San Francisco", latitude: 37.774929, longitude: -122.419416, utm: "10S 551129 4181002", mgrs: "10SEG 51129 81002"),
    ]

    let testCitiesLowerPrecision: [TestLocationModel] = [
      TestLocationModel(name: "Sydney_1metre", latitude: -33.867487, longitude: 151.20699, utm: "56H 334152 6251090", mgrs: "56HLH 34152 51090"),
      TestLocationModel(name: "Sydney_10metres", latitude: -33.867487, longitude: 151.20699, utm: "56H 334152 6251090", mgrs: "56HLH 3415 5109"),
      TestLocationModel(name: "Sydney_100metres", latitude: -33.867487, longitude: 151.20699, utm: "56H 334152 6251090", mgrs: "56HLH 341 510"),
    ]

    func testInvalidLatitude() throws {
      XCTAssertThrowsError(try GeoCoordinateConverter.validateLatLong(latitude: -91, longitude: 0))
      XCTAssertThrowsError(try GeoCoordinateConverter.validateLatLong(latitude: 91, longitude: 0))
    }

    func testValidLatitude() throws {
      XCTAssertNoThrow(try GeoCoordinateConverter.validateLatLong(latitude: -90, longitude: 0))
      XCTAssertNoThrow(try GeoCoordinateConverter.validateLatLong(latitude: 90, longitude: 0))
    }

    func testInvalidLongitude() throws {
      XCTAssertThrowsError(try GeoCoordinateConverter.validateLatLong(latitude: 0, longitude: -181))
      XCTAssertThrowsError(try GeoCoordinateConverter.validateLatLong(latitude: 0, longitude: 181))
    }

    func testValidLongitude() throws {
      XCTAssertNoThrow(try GeoCoordinateConverter.validateLatLong(latitude: 0, longitude: -180))
      XCTAssertNoThrow(try GeoCoordinateConverter.validateLatLong(latitude: 0, longitude: 180))
    }

    func testLatLongToUTM() throws {
      testCities.forEach {
        XCTAssertEqual(
          $0.utm,
          utm.convertFromDecimalDegrees(latitude: $0.latitude, longitude: $0.longitude),
          "Mismatched UTM value for \($0.name)")
      }
    }

    func testLatLongToMGRS() throws {
      testCities.forEach {
        XCTAssertEqual(
          $0.mgrs,
          mgrs.convertFromDecimalDegrees(latitude: $0.latitude, longitude: $0.longitude),
          "Mismatched MGRS value for \($0.name)")
      }
    }

    func testUTMToLatLong() throws {
      try testCities.forEach { city in
        try XCTAssertEqual(city.latitude, utm.convertToDecimalDegrees(reference: city.utm).latitude, accuracy: 0.0001)
        try XCTAssertEqual(city.longitude, utm.convertToDecimalDegrees(reference: city.utm).longitude, accuracy: 0.0001)
      }
    }

    func testMGRSToLatLong() throws {
      try testCities.forEach { city in
        let conversion = try mgrs.convertToDecimalDegrees(reference: city.mgrs)

        XCTAssertNoThrow(MGRSConversionError.invalidSetValue, "\(city.name)")
        XCTAssertNoThrow(MGRSConversionError.invalidMGRSFormat, "\(city.name)")
        XCTAssertNoThrow(MGRSConversionError.invalidNorthingLetter, "\(city.name)")
        XCTAssertNoThrow(MGRSConversionError.invalidZoneLetter, "\(city.name)")

        // Note: these will start failing the accuracy tests at around 1km (e.g 56HLH 34 51), but that's
        // acceptable since it's lower precision. These cases have been abstracted into its own test case and data set
        XCTAssertEqual(city.latitude, conversion.latitude, accuracy: 0.001)
        XCTAssertEqual(city.longitude, conversion.longitude, accuracy: 0.001)
      }
    }

    func testLowPrecisionMGRSToLatLong() throws {
      try testCitiesLowerPrecision.forEach { city in
        let conversion = try mgrs.convertToDecimalDegrees(reference: city.mgrs)

        XCTAssertNoThrow(MGRSConversionError.invalidSetValue, "\(city.name)")
        XCTAssertNoThrow(MGRSConversionError.invalidMGRSFormat, "\(city.name)")
        XCTAssertNoThrow(MGRSConversionError.invalidNorthingLetter, "\(city.name)")
        XCTAssertNoThrow(MGRSConversionError.invalidZoneLetter, "\(city.name)")

        // Note: these will start failing the accuracy tests at around 1km (e.g 56HLH 34 51), but that's
        // acceptable since it's lower precision
        XCTAssertEqual(city.latitude, conversion.latitude, accuracy: 0.1)
        XCTAssertEqual(city.longitude, conversion.longitude, accuracy: 0.1)
      }
    }

    static var allTests = [
        ("testInvalidLatitude", testInvalidLatitude),
        ("testInvalidLatitude", testValidLatitude),
        ("testInvalidLatitude", testInvalidLongitude),
        ("testInvalidLatitude", testValidLongitude),
    ]
}
