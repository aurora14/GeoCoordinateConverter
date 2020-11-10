//
//  GridZoneRect.swift
//  GeoCoordinateConverter
//
//  Created by Alexei Gudimenko on 28/10/20.
//  Copyright © 2020 AG. All rights reserved.
//

/// UTM Grid Rectangle.
///
/// For use with MGRS, this is further subdivided into smaller segments
struct GridZoneRect {

    let longitudeZoneValue: Int
    let latitudeZoneValue: Int
    let eastingValue: Double
    let northingValue: Double
}
