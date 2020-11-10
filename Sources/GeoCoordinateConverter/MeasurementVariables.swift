//
// SOIKit
// Copyright © 2020 Forest Fire Management Victoria. All rights reserved.
//

import Foundation

// Note that some of the variables here (and in other classes) were named in a very shorthand manner in the original project.
// To that end, where practical and possible, they've been looked up and renamed, but this isn't true for all instances

///
struct MeasurementsAndMultipliers {

  typealias GlobalConstants = GeoCoordinateConverter.Constants

  /// Values to use when converting from WGS84 -> UTM/MGRS
  struct To {
    let k: Double = 1
    /// The scale factor at the central meridian is specified to be 0.9996 of true scale for most UTM systems in use.
    ///
    /// See also https://en.wikipedia.org/wiki/Universal_Transverse_Mercator_coordinate_system
    let k0: Double = 0.9996

    let equatorialRadius = GlobalConstants.equatorialRadius
    let inverseFlattening = 1 / GlobalConstants.flattening

    var polarRadius: Double {
      equatorialRadius * (1 - inverseFlattening)
    }

    /// Eccentricity of a conic section, i.e a non-negative real number that uniquely characterizes its shape
    ///
    /// See also [Eccentricity](https://en.wikipedia.org/wiki/Eccentricity_(mathematics))
    var e: Double {
      let expression = 1 - pow(polarRadius, 2) / pow(equatorialRadius, 2)
      return sqrt(expression < 0
                    ? 0
                    : expression)
    }

    var e0: Double {
      e / sqrt(1 - pow(e, 1))
    }

    var esq: Double {
      // Note: can probably be simplified by extracting polar radius / eq radius into its own variable, and using something like pow(radiusDividend, 2)
      1 - (polarRadius / equatorialRadius) * (polarRadius / equatorialRadius)
    }

    var e0sq: Double {
      e * e / (1 - pow(e, 2))
    }
  }

  /// Values to use when converting from URM/MGRS -> Lat/Long
  ///
  /// Note, these are practically identical to 'To' values, but they were defined in a separate part of the code in the original ObjC project
  struct From {
    let southernHemisphere = "ACDEFGHJKLM"

    let k: Double = 1

    /// The scale factor at the central meridian is specified to be 0.9996 of true scale for most UTM systems in use.
    ///
    /// See also https://en.wikipedia.org/wiki/Universal_Transverse_Mercator_coordinate_system
    let k0: Double = 0.9996

    let equatorialRadius: Double = GlobalConstants.equatorialRadius
    let inverseFlattening: Double = 1 / GlobalConstants.flattening

    var polarRadius: Double {
      equatorialRadius * (1 - inverseFlattening)
    }

    var e: Double {
      let expression = 1 - pow(polarRadius, 2) / pow(equatorialRadius, 2)
      return sqrt(expression < 0
                    ? 0
                    : expression)
    }

    var esq: Double {
      // Note: can probably be simplified by extracting polar radius / eq radius into its own variable, and using something like pow(radiusDividend, 2)
      1 - (polarRadius / equatorialRadius) * (polarRadius / equatorialRadius)
    }

    var e0sq: Double {
      e * e / (1 - pow(e, 2))
    }
  }
}
