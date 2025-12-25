// SPDX-License-Identifier: MIT

import Foundation

struct Resources {
    static let containeredLibraryDirectory = URL.libraryDirectory.appending(
        path: "Containers/com.apple.Safari/Data/Library")
    static let containeredCookiesFile = containeredLibraryDirectory.appending(
        path: "Cookies/Cookies.binarycookies")
    static let containeredSafariTabsFile = containeredLibraryDirectory.appending(
        path: "Safari/SafariTabs.db")

    static let bookmarksFile = URL.libraryDirectory.appending(path: "Safari/Bookmarks.plist")
}
