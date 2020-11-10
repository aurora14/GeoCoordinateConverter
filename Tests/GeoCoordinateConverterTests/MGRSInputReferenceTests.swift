//
// SOIKitTests
// Copyright © 2020 Forest Fire Management Victoria. All rights reserved.
//

import XCTest
@testable import GeoCoordinateConverter

final class MGRSInputReferenceTests: XCTestCase {

  let validTestStrings = [
    "55HCU 20704 12911",
    "55HCU 2070 1291",
    "55HCU 207 129",
    "5HCU 207 129"
  ]

  let invalidTestStrings = [
    "5HCU207 129",
    "23243235",
    "55HCU 20704 1291",
  ]

  func testMGRSRegexValidation() {
    validTestStrings.forEach { mgrsString in
      XCTAssertTrue(mgrsString.isValidMGRS, "Validation failed for \(mgrsString), test string is valid but the regex failed.")
    }

    invalidTestStrings.forEach { mgrsString in
      XCTAssertFalse(mgrsString.isValidMGRS, "Validation failed for \(mgrsString), test string is invalid but the regex thought it's fine.")
    }
  }
}
