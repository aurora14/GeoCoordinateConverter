//
// SOIKit
// Copyright © 2020 Forest Fire Management Victoria. All rights reserved.
//

import Foundation

public extension String {

  var isValidMGRS: Bool {

    let components = self.split(separator: " ")

    // Valid UTM string format: <zone><latitude band> <easting> <northing>, so we should have 3 components
    guard components.count == 3 else {
      return false
    }

    guard components[1].count == components[2].count else {
      return false
    }

    let eastingNorthingCharCount: Int = components.last?.count ?? 0

    do {
      let rawRegexString = #"^[0-9]{1,2}[A-Z]{3}\h{1}[0-9]{\#(eastingNorthingCharCount)}\h{1}[0-9]{\#(eastingNorthingCharCount)}$"#
      let regex = try NSRegularExpression(pattern: rawRegexString)
      return regex.matches(self)
    } catch {
      print("*** Invalid regular expression: \(error)")
      return false
    }
  }
}
