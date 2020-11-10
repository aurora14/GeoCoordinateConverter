//
//  GeoCoordinateConverter.swift
//  GeoCoordinateConverter
//
//  Created by Alexei Gudimenko on 27/10/20.
//  Copyright © 2020 AG. All rights reserved.
//
//  Adapted from

import Foundation
import CoreLocation

enum GeoCoordinateConverterError: Error {
  case invalidLatitudeValue(message: String)
  case invalidLongitudeValue(message: String)
}

final class GeoCoordinateConverter {

  struct Constants {
    static let equatorialRadius: CLLocationDistance = 6_378_137.0

    /// Measure of the compression of a circle or sphere along a diameter to form an ellipse or an ellipsoid of revolution (spheroid) respectively.
    ///
    /// Used for calculations involving representation of the WSG84 ellipsoid model of Earth
    ///
    /// - Note: also see [flattening](https://en.wikipedia.org/wiki/Flattening)
    static let flattening: Double = 298.2572236

    static let northPole: CLLocationDegrees = 90
    static let southPole: CLLocationDegrees = -90

    /// Easternmost point from Greenwich meridian (0)
    static let easternEdge: CLLocationDegrees = 180
    /// Westernmost point from Greenwich meridian (0)
    static let westernEdge: CLLocationDegrees = -180

    // Polar region thresholds:

    /// In the polar regions, a different convention is used. South of 80°S, UPS South (Universal Polar Stereographic) is used instead of a UTM projection.
    static let southernPolarThreshold: CLLocationDegrees = -80
    /// In the polar regions, a different convention is used. North of 84°N, UPS North is used instead of a UTM projection
    static let northernPolarThreshold: CLLocationDegrees = 84

    // latitude band height and utm zone width form a 6 * 8 polygon

    /// Height of the grid rectangle in a UTM or MGRS system
    ///
    /// Each rectangle is 8 degrees high
    static let latitudeBandHeightInDegrees: CLLocationDegrees = 8

    /// Width of the grid rectangle in a UTM or MGRS system
    ///
    /// Each rectangle is 6 degrees wide
    static let utmZoneWidthInDegrees: CLLocationDegrees = 6
  }

  static func validateLatLong(latitude: CLLocationDegrees, longitude: CLLocationDegrees) throws {
    if latitude < Constants.southPole || latitude > Constants.northPole {
      let message = """
            latitude outside of allowable range. Must be between -90 and 90. Provided value: \(latitude)
            """
      throw GeoCoordinateConverterError.invalidLatitudeValue(message: message)
    }

    if longitude < Constants.westernEdge || longitude > Constants.easternEdge {
      let message = """
            longitude outside of allowable range. Must be between -180 and 180. Provided value: \(longitude)
            """
      throw GeoCoordinateConverterError.invalidLongitudeValue(message: message)
    }
  }

  static func getReferenceGridRectFrom(latitude: CLLocationDegrees, longitude: CLLocationDegrees) -> GridZoneRect {
    let measurementVars = MeasurementsAndMultipliers.To()

    let latitudeRadians: Double = latitude * Double.pi / 180.0
    let utmZone: Double = 1 + floor((longitude + 180) / Constants.utmZoneWidthInDegrees) // utm zone
    let zoneCentralMeridian: Double = 3 + Constants.utmZoneWidthInDegrees * (utmZone - 1) - 180 // central meridian of a zone
    var latitudeZone: Double = 0

    // 1. Convert latitude to latitude zone. Check whether regular zone or one of special cases (e.g polar regions)
    // See also https://en.wikipedia.org/wiki/Military_Grid_Reference_System#Squares_that_cross_a_latitude_band_boundary
    if latitude > Constants.southernPolarThreshold && latitude < 72 {
      latitudeZone = floor((latitude + 80) / 8) + 2 // zones C-W
    } else {
      if latitude > Constants.northernPolarThreshold {
        latitudeZone = 23 // zones Y-Z
      }
    }

    let a = measurementVars.equatorialRadius
    let e = measurementVars.e
    let esq = measurementVars.esq
    let e0sq = measurementVars.e0sq
    let k0 = measurementVars.k0

    let N: Double = a / sqrt(1 - pow(e * sin(latitudeRadians), 2))
    let T: Double = pow(tan(latitudeRadians), 2)
    let C: Double = e0sq * pow(cos(latitudeRadians), 2)
    let A: Double = (longitude - zoneCentralMeridian) * Double.pi / 180.0 * cos(latitudeRadians)

    // 2. calculate M (USGS style)
    var M: Double = latitudeRadians * (1.0 - esq * (1.0 / 4.0 + esq * (3.0 / 64.0 + 5.0 * esq / 256.0)))
    M = M - sin(2.0 * latitudeRadians) * (esq * (3.0 / 8.0 + esq * (3.0 / 32.0 + 45.0 * esq / 1024.0)))
    M = M + sin(4.0 * latitudeRadians) * (esq * esq * (15.0 / 256.0 + esq * 45.0 / 1024.0))
    M = M - sin(6.0 * latitudeRadians) * (esq * esq * esq * (35.0 / 3072.0))
    M = M * a //Arc length along standard meridian

    // 3. calculate easting
    var x: Double = k0 * N * A * (1.0 + A * A * ((1.0 - T + C) / 6.0 + A * A * (5.0 - 18.0 * T + T * T + 72.0 * C - 58.0 * e0sq) / 120.0)) //Easting relative to CM

    x = x + 500_000 // standard easting

    // 4. calculate northing
    var y: Double = k0 * (M + N * tan(latitudeRadians) * (A * A * (1.0 / 2.0 + A * A * ((5.0 - T + 9.0 * C + 4.0 * C * C) / 24.0 + A * A * (61.0 - 58.0 * T + T * T + 600.0 * C - 330.0 * e0sq) / 720.0)))) // from the equator

    if y < 0 {
      y = 10_000_000 + y // add in false northing if south of the equator
    }

    let longitudeZoneValue = Int(utmZone)
    let latitudeZoneValue = Int(latitudeZone)
    let eastingValue = x
    let northingValue = y

    return GridZoneRect(
      longitudeZoneValue: longitudeZoneValue,
      latitudeZoneValue: latitudeZoneValue,
      eastingValue: eastingValue,
      northingValue: northingValue
    )
  }
}
