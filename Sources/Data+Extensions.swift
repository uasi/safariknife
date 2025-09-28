// SPDX-License-Identifier: MIT

import Foundation

extension Data {
    mutating func append(string: String) {
        self.append(contentsOf: string.utf8)
    }

    mutating func appendLineFeed() {
        self.append(0x0A)
    }

    mutating func appendTab() {
        self.append(0x09)
    }
}
