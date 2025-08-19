// SPDX-License-Identifier: MIT

import Foundation

struct StandardError: TextOutputStream {
    nonisolated(unsafe) static var shared = Self()

    func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}
