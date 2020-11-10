//
// SOIKit
// Copyright © 2020 Forest Fire Management Victoria. All rights reserved.
//

import Foundation

extension NSRegularExpression {
  func matches(_ string: String) -> Bool {
    let range = NSRange(location: 0, length: string.utf16.count)
    return firstMatch(in: string, range: range) != nil
  }
}
