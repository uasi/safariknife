// SPDX-License-Identifier: MIT

import Foundation

struct Cookie: Encodable {
    private static let isSecureFlag: UInt = 1
    private static let isHTTPOnlyFlag: UInt = 4

    let version: UInt
    let name: String
    let value: String
    let domain: String
    let path: String
    let portList: [UInt]
    let expiresDate: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool
    let comment: String?
    let commentURL: String?

    init(
        version: UInt = 0,
        name: String,
        value: String,
        domain: String,
        path: String,
        portList: [UInt],
        expiresDate: Date? = nil,
        flags: UInt,
        comment: String? = nil,
        commentURL: String? = nil
    ) {
        self.version = version
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.portList = portList
        self.expiresDate = expiresDate
        self.isSecure = flags & Self.isSecureFlag != 0
        self.isHTTPOnly = flags & Self.isHTTPOnlyFlag != 0
        self.comment = comment
        self.commentURL = commentURL
    }
}
