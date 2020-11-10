//
//  MGRS.swift
//  GeoCoordinateConverter
//
//  Created by Alexei Gudimenko on 27/10/20.
//  Copyright © 2020 AG. All rights reserved.
//

import Foundation
import CoreLocation

enum MGRSConversionError: Error {
  case invalidZoneLetter(message: String)
  case invalidNorthingLetter(message: String)
  case invalidSetValue(message: String)
  case invalidMGRSFormat(message: String)
}

/// Converts MGRS map reference values from and to WGS84 map reference (lat/long decimal degrees)
///
/// - Note: MGRS = Military Grid Reference System, an adaptation of UTM with higher precision
struct LatLongMGRS: GeoConversionProviding {

  typealias Reference = MGRSReference

  /// Describes number of digits required for the northing and easting components, based on precision of the grid. E.g: 1 = there must be exactly 1 digit in the Northing component and exactly 1 digit in the Easting component, making up 2 digits together (the total number of digits must always be even), and representing a 10km grid square precision level, i.e grid square side length.
  ///
  /// Measurements, Terms, Units and Values:
  /// * GZD - Grid Zone Designator
  /// * Northings - `Easting` and `northing` are geographic Cartesian coordinates for a point. `Northing` is the northward-measured distance (or the `y-coordinate`)
  /// * Eastings - `Easting` and `northing` are geographic Cartesian coordinates for a point. Easting is the eastward-measured distance (or the `x-coordinate`)
  ///
  /// Example data:
  /// * `4QFJ 12345 67890` - Location at Honolulu Airport with 10m precision
  enum Precision: Int {
    /// GZD and 100 km grid square ID. No northing/easting values
    ///
    /// Example value: `4QFJ`
    case oneHundredKM = 0

    /// GZD and 10 km grid square ID. One `northing`, one `easting` value
    ///
    /// Example value: `4QFJ 1 6`
    case tenKm = 1

    /// GZD and 1 km grid square ID. Two `northing`, two `easting` values
    ///
    /// Example value: `4QFJ 12 67`
    case oneKm = 2

    /// GZD and 100 m grid square ID. Three `northing`, three `easting` values
    ///
    /// Example value: `4QFJ 123 678`
    case oneHundredMetres = 3

    /// GZD and 10 m grid square ID. Four `northing`, four `easting` values
    ///
    /// Example value: `4QFJ 1234 6789`
    case tenMetres = 4

    /// GZD and 1 m grid square ID. Five `northing`, five `easting` values
    ///
    /// Maximum possible precision within this system
    ///
    /// Example value: `4QFJ 12345 67890`
    case oneMetre = 5

    /// Grid Zone Designator only, precision level 6° (width) by 8° (height)
    ///
    /// e.g `4Q`
    case none = 6
  }

  // MARK: - Domain-specific and helper constants

  struct Constants {
    /// https://en.wikipedia.org/wiki/Military_Grid_Reference_System#100,000-meter_square_identification
    ///
    /// The second part of an MGRS coordinate is the 100,000-meter square identification. Each UTM zone is divided into 100,000 meter squares, so that their corners have UTM-coordinates that are multiples of 100,000 meters. The identification consists of a column letter (A–Z, omitting I and O) followed by a row letter (A–V, omitting I and O).
    ///
    /// - Note: this numbere is present but uncommented in the original project,it would be extremely useful to understand its source and exact application. Linking the wiki article as the starting point for this follow-up and as a basic reference
    static let squareMetreIdentification100000: Double = 100000

    static let digraphCount: Int = 24

    static let defaultMelbourneMGRSReference = "55H"
  }

  // MARK: - Conversion-specific properties

  private let numOf100kSets = 6

  private let originColumnLetters: [String] = [
    "A", "J", "S", "A", "J", "S"
  ]

  private let originRowLetters: [String] = [
    "A", "F", "A", "F", "A", "F"
  ]

  // MARK: - Initialisation
  init() {
  }

  // MARK: - Public conversion API

  func convertFromDecimalDegrees(latitude: CLLocationDegrees, longitude: CLLocationDegrees) -> Reference {

    do {
      try GeoCoordinateConverter.validateLatLong(latitude: latitude, longitude: longitude)

      let gridRectangle = GeoCoordinateConverter.getReferenceGridRectFrom(latitude: latitude, longitude: longitude)

      let digraph = calcDigraph(
        longitudeZoneValue: gridRectangle.longitudeZoneValue,
        eastingValue: gridRectangle.eastingValue,
        northingValue: gridRectangle.northingValue
      )
      let eastingString = formatting(value: gridRectangle.eastingValue)
      let northingString = formatting(value: gridRectangle.northingValue)

      return String(
        format: "%d%@%@ %@ %@",
        gridRectangle.longitudeZoneValue, digraphArrayN[gridRectangle.latitudeZoneValue], digraph, eastingString, northingString
      )
    } catch {
      print("Invalid coordinate data -> \(error)")
      return Constants.defaultMelbourneMGRSReference
    }
  }

  func convertToDecimalDegrees(reference: Reference) throws -> CLLocationCoordinate2D {

    let mgrsString = reference.uppercased()

    let utmZoneCharacterIndex: String.Index

    if mgrsString[mgrsString.index(mgrsString.startIndex, offsetBy: 1)].isNumber {
      utmZoneCharacterIndex = mgrsString.index(mgrsString.startIndex, offsetBy: 2)
    } else {
      utmZoneCharacterIndex = mgrsString.index(mgrsString.startIndex, offsetBy: 1)
    }

    let utmZoneNumber = Int(mgrsString[..<utmZoneCharacterIndex]) ?? 0
    let utmZoneChar = String(mgrsString[utmZoneCharacterIndex])
    let eastingID = String(mgrsString[mgrsString.index(after: utmZoneCharacterIndex)]) // utmZoneCharacterIndex + 1
    let northingID = String(mgrsString[mgrsString.index(utmZoneCharacterIndex, offsetBy: 2)]) // utmZoneCharacterIndex + 2

    let set = get100kSetForZone(utmZoneNumber)

    let east100k = try getEastingFrom(letter: eastingID, set: set)
    var north100k = try getNorthingFrom(letter: northingID, set: set)

    let minNorthing = try getMinNorthingFor(zone: utmZoneChar)

    while north100k < minNorthing {
      north100k += 2_000_000
    }

    // Validate that MGRS string is in the correct format.
    // <easting>, <northing> + two separating spaces (see error message example below) must always total to an even number.
    let validationSubstringIndex = mgrsString.index(utmZoneCharacterIndex, offsetBy: 3)

    /// Character count of the rest of the MGRS string (excluding Zone and Latitude Band), accounting for the easting and northing numeric values
    let remainder = mgrsString[mgrsString.index(after: validationSubstringIndex)...].count

    guard remainder % 2 == 1 else { // easting/northing + separator whitespace
      let message = "Valid MGRS string format: <zone><latitude band> <easting> <northing>"
      throw MGRSConversionError.invalidMGRSFormat(message: message)
    }

    // mid point offset of the 'remainder' string
    let sep = remainder / 2

    var sepEasting = 0.0
    var sepNorthing = 0.0

    if sep > 0 {
      let accuracyBonus = 100_000 / pow(10.0, Double(sep))
      let eastingEndIndex = mgrsString.index(validationSubstringIndex, offsetBy: sep)
      let eastingString = mgrsString[validationSubstringIndex...eastingEndIndex].trimmingCharacters(in: .whitespacesAndNewlines)
      let northingString = mgrsString[mgrsString.index(after: eastingEndIndex)...].replacingOccurrences(of: " ", with: "")

      sepEasting = (Double(eastingString) ?? 0.0) * accuracyBonus
      sepNorthing = (Double(northingString) ?? 0.0) * accuracyBonus
    }

    let easting = sepEasting + east100k
    let northing = sepNorthing + north100k

    let utmString = String(format: "%d %@ %d %d", utmZoneNumber, utmZoneChar, Int(easting), Int(northing))

    return try LatLongUTM().convertToDecimalDegrees(reference: utmString)
  }

  // MARK: - Private helpers

  private func calcDigraph(longitudeZoneValue: Int, eastingValue: Double, northingValue: Double, precision: Precision = .oneMetre) -> String {
    let eastingValueFraction = eastingValue / Constants.squareMetreIdentification100000

    var letter: Int = Int(floor(Double((longitudeZoneValue - 1)) * GeoCoordinateConverter.Constants.latitudeBandHeightInDegrees + eastingValueFraction))
    var letterIndex: Int = ((letter % Constants.digraphCount) + 23) % Constants.digraphCount

    let digraph = digraphArrayE[letterIndex]

    letter = Int(floor(northingValue / Constants.squareMetreIdentification100000))
    if Double(longitudeZoneValue) / 2.0 == floor(Double(longitudeZoneValue) / 2.0) {
      // not sure if the original project made all the calcs based on one metre precision and then truncated the strings down,
      // but for now I'm assuming this can be variable? This is something that needs to be tested
      letter = letter + precision.rawValue
    }

    letterIndex = letter - 20 * Int(floor(Double(letter) / 20.0))

    return digraph.appending(digraphArrayN[letterIndex])
  }

  private func formatting(value: Double) -> String {
    var str = String(format: "%d", Int(round(value - Constants.squareMetreIdentification100000 * floor(value / Constants.squareMetreIdentification100000))))

    // Padding to five places, if the initial conversion is shorter in length
    if str.count < Precision.oneMetre.rawValue {
      str = String(format: "00000%@", str)
    }

    return String(str.suffix(Precision.oneMetre.rawValue))
  }

  private func get100kSetForZone(_ i: Int) -> Int {
    let set = i % numOf100kSets
    return set == 0 ? numOf100kSets : set
  }

  private func getEastingFrom(letter: String, set: Int) throws -> Double {
    guard set > 0, set <= 6 else {
      throw MGRSConversionError.invalidSetValue(message: "Set must be above 0 and below or equal to 6. Found: \(set)")
    }

    var eastingValue: Double = 100_000
    var currentColumn = originColumnLetters[set - 1]

    let startingIndex = digraphArrayN.index(after: digraphArrayN.firstIndex(of: currentColumn) ?? digraphArrayE.startIndex)
    let referenceArray = digraphArrayE[startingIndex...]

    for value in referenceArray {
      if currentColumn != letter {
        currentColumn = value
        eastingValue += 100_000
      } else {
        break
      }
    }

    return eastingValue
  }

  private func getNorthingFrom(letter: String, set: Int) throws -> Double {
    guard set > 0, set <= 6 else {
      throw MGRSConversionError.invalidSetValue(message: "Set must be above 0 and below or equal to 6. Found: \(set)")
    }

    var rewindMarker = false

    switch letter {
    case "W", "X", "Y", "Z":
      // this was the rule in the original project that this code was adapted from
      throw MGRSConversionError.invalidNorthingLetter(message: "Bad character (supplied param); should not include W, X, Y or Z, found: \(letter)")
    default:
      var northingValue: Double = 0
      var currentRow = originRowLetters[set - 1]

      // In theory we should never hit 'startIndex', however it's best to guard against.
      let startingIndex = digraphArrayN.index(after: digraphArrayN.firstIndex(of: currentRow) ?? digraphArrayN.startIndex)
      let referenceArray = digraphArrayN[startingIndex...]

      for value in referenceArray {

        switch currentRow {
        case "W", "X", "Y", "Z":
          if rewindMarker {
            break
          }

          currentRow = "A"
          northingValue += 100_000
          rewindMarker = true

        default:
          if currentRow != letter {
            currentRow = value
            northingValue += 100_000
          } else {
            break
          }
        }
      }

      return northingValue
    }

  }

  private func getMinNorthingFor(zone letter: String) throws -> Double {
    var northing: Double = 0.0

    switch letter {
    case "C":
      northing = 1_100_000
    case "D":
      northing = 2_000_000
    case "E":
      northing = 2_800_000
    case "F":
      northing = 3_700_000
    case "G":
      northing = 4_600_000
    case "H":
      northing = 5_500_000
    case "J":
      northing = 6_400_000
    case "K":
      northing = 7_300_000
    case "L":
      northing = 8_200_000
    case "M":
      northing = 9_100_000
    case "N":
      northing = 0.0
    case "P":
      northing = 800_000
    case "Q":
      northing = 1_700_000
    case "R":
      northing = 2_600_000
    case "S":
      northing = 3_500_000
    case "T":
      northing = 4_400_000
    case "U":
      northing = 5_300_000
    case "V":
      northing = 6_200_000
    case "W":
      northing = 7_000_000
    case "X":
      northing = 7_900_000
    default:
      northing = -1.0
    }

    guard northing >= 0.0 else {
      let message = "Invalid zone letter '\(letter)' provided as argument"
      throw MGRSConversionError.invalidZoneLetter(message: message)
    }

    return northing
  }
}
