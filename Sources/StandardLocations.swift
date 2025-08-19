// SPDX-License-Identifier: MIT

import Foundation

struct StandardLocations {
    static let containeredLibraryDirectory = URL.libraryDirectory.appending(
        path: "Containers/com.apple.Safari/Data/Library")
    static let containeredCookiesFile = containeredLibraryDirectory.appending(
        path: "Cookies/Cookies.binarycookies")
}
