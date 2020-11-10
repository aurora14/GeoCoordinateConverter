//
// SOIKit
// Copyright © 2020 Forest Fire Management Victoria. All rights reserved.
//

import Foundation
import CoreLocation

protocol GeoConversionProviding {
  associatedtype Reference

  /// UTM/MGRS Grid - column letter identifiers
  var digraphArrayE: [DigraphComponent] { get }

  /// UTM/MGRS Grid - row letter identifiers
  var digraphArrayN: [DigraphComponent] { get }

  func convertFromDecimalDegrees(latitude: CLLocationDegrees, longitude: CLLocationDegrees) -> Reference

  func convertToDecimalDegrees(reference: Reference) throws -> CLLocationCoordinate2D
}

extension GeoConversionProviding {

  var digraphArrayE: [DigraphComponent] {
    [
      "A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
    ]
  }

  var digraphArrayN: [DigraphComponent] {
    [
      "A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"
    ]
  }
}
