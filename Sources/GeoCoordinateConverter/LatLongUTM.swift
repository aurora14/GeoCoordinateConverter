//
//  UTM.swift
//  GeoCoordinateConverter
//
//  Created by Alexei Gudimenko on 27/10/20.
//  Copyright © 2020 AG. All rights reserved.
//

import Foundation
import CoreLocation

enum LatLongUTMError: Error {
  case invalidUTMString(message: String)
}

/// Converts WGS84 map reference (lat/long decimal degrees) to UTM map reference values from and to 
public struct LatLongUTM: GeoConversionProviding {

  public typealias Reference = UTMReference

  struct Constants {
    // Source: https://www.e-education.psu.edu/natureofgeoinfo/c2_p23.html
    // Source: http://www.land-navigation.com/utm_grid.html
    static let minNorthingZoneHeight = 1_000_000.0 // in metres
    static let maxNorthingZoneHeight = 10_000_000.0 // in metres
    /// Any easting value less than 500_000 metres describes a location _west_ of the zone meridian,
    /// and any easting value greater than 500_000m describes a location _east_ of the zone meridian.
    /// The grid that overlays each zone is 1_000_000 m wide
    static let eastingGridWidthMidpoint = 500_000.0 // in metres
    static let oneDegreeInRadians = Double.pi / 180.0
  }

  public init() {}

  public func convertFromDecimalDegrees(latitude: CLLocationDegrees, longitude: CLLocationDegrees) -> Reference {

    do {
      try GeoCoordinateConverter.validateLatLong(latitude: latitude, longitude: longitude)
      let gridRectangle = GeoCoordinateConverter.getReferenceGridRectFrom(latitude: latitude, longitude: longitude)

      let reference = String(
        format: "%d%@ %d %d",
        gridRectangle.longitudeZoneValue,
        digraphArrayN[gridRectangle.latitudeZoneValue],
        Int(round(gridRectangle.eastingValue)),
        Int(round(gridRectangle.northingValue))
      )

      return reference
    } catch {
      assertionFailure("Invalid coordinates supplied: \(error)")
      return "55H" // Melbourne, no precision
    }
  }

  func getHemisphereFrom(latitudeZone latZone: String) -> Hemisphere {
    let measurements = MeasurementsAndMultipliers.From()
    let hemisphere: Hemisphere = measurements.southernHemisphere.contains(latZone) ? .south : .north
    return hemisphere
  }
  
  public func convertToDecimalDegrees(reference: UTMReference) throws -> CLLocationCoordinate2D {

    let measurements = MeasurementsAndMultipliers.From()

    let zone: Int
    let latZone: String
    let easting: Double
    let northing: Double

    let referenceComponents = reference.components(separatedBy: " ")

    // TODO: - replace all NSString conversions with String and String.Index equivalents
    // This is low-priority tech debt that's addressed somewhat better in the LatLongMGRS class
    // At the time of writing this code, the goal was to stick as close to implementation of the
    // project used as source to avoid discrepancies

    switch referenceComponents.count {
    case 4: //the numeric and letter components are separated by a space, e.g 10 S 551129 4181002
      zone = Int(NSString(string: referenceComponents[0]).intValue)
      latZone = referenceComponents[1]
      easting = NSString(string: referenceComponents[2]).doubleValue
      northing = NSString(string: referenceComponents[3]).doubleValue
    case 3: //the numeric and letter components are not separated by a space, e.g 10S 551129 4181002
      // 1. Is the numeric component composed of 1 or 2 digits?
      let utmZoneCharacterIndex = reference[reference.index(after: reference.startIndex)].isNumber ? 2 : 1
      let zoneNumberString = NSString(string: referenceComponents[0]).substring(to: utmZoneCharacterIndex)
      // 2. Infer the zone from the numeric range of the first reference component
      zone = Int(NSString(string: zoneNumberString).intValue) // Don't even ask... - A.G
      // 3. Infer the lat zone from the rest of the first reference component
      latZone = NSString(string: referenceComponents[0]).substring(from: utmZoneCharacterIndex)

      easting = NSString(string: referenceComponents[1]).doubleValue
      northing = NSString(string: referenceComponents[2]).doubleValue
    default:
      throw LatLongUTMError.invalidUTMString(message: "Valid UTM string format: <zone><latitude band> <easting> <northing>")
    }

    let hemisphere = getHemisphereFrom(latitudeZone: latZone)

    let esq = measurements.esq
    let e0sq = measurements.e0sq
    let zcm: Double = Double(3 + 6 * (zone - 1)) - 180.0 // Central meridian of zone
    let e1: Double = (1.0 - sqrt(1 - pow(measurements.e, 2))) / (1.0 + sqrt(1 - pow(measurements.e, 2)))
    let e = measurements.e
    let k0 = measurements.k0

    // if 'north', equals to arc length along standard meridian
    let M: Double = hemisphere == .north ? northing / measurements.k0 : (northing - Constants.maxNorthingZoneHeight) / measurements.k0

    let mu: Double = M / (measurements.equatorialRadius * (1.0 - esq * (1.0 / 4.0 + esq * (3.0 / 64.0 + 5.0 * esq / 256.0))))
    var phi1: Double = mu + e1 * (3.0 / 2.0 - 27.0 * e1 * e1 / 32.0) * sin(2.0 * mu) + e1 * e1 * (21.0 / 16.0 - 55.0 * e1 * e1 / 32.0) * sin(4.0 * mu)

    //Footprint Latitude
    phi1 = phi1 + e1 * e1 * e1 * (sin(6.0 * mu) * 151.0 / 96.0 + e1 * sin(8.0 * mu) * 1097.0 / 512.0)
    let C1: Double = e0sq * pow(cos(phi1), 2)
    let T1: Double = pow(tan(phi1), 2)
    let N1: Double = measurements.equatorialRadius / sqrt(1.0 - pow(measurements.e * sin(phi1), 2))
    let R1: Double = N1 * (1.0 - pow(e, 2)) / (1.0 - pow(e * sin(phi1), 2))
    let D: Double = (easting - Constants.eastingGridWidthMidpoint) / (N1 * k0)
    var phi: Double = (D * D) * (1.0 / 2.0 - D * D * (5.0 + 3.0 * T1 + 10.0 * C1 - 4.0 * C1 * C1 - 9.0 * e0sq) / 24.0)
    phi = phi + pow(D, 6) * (61.0 + 90.0 * T1 + 298.0 * C1 + 45.0 * T1 * T1 - 252.0 * e0sq - 3.0 * C1 * C1) / 720.0
    phi = phi1 - (N1 * tan(phi1) / R1) * phi

    let latitude: Double = floor(Constants.minNorthingZoneHeight * phi / (Constants.oneDegreeInRadians)) / Constants.minNorthingZoneHeight
    var longitude: Double = D * (1.0 + D * D * ((-1.0 - 2.0 * T1 - C1) / 6.0 + D * D * (5.0 - 2.0 * C1 + 28.0 * T1 - 3.0 * C1 * C1 + 8.0 * e0sq + 24.0 * T1 * T1) / 120.0)) / cos(phi1)
    longitude = zcm + longitude / (Constants.oneDegreeInRadians)

    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}
