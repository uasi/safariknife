// SPDX-License-Identifier: MIT

import Foundation

struct BinaryCookiesParser {
    enum ParsingError: Error {
        case invalidData(offset: UInt, kind: String)
        case insufficientData(offset: UInt, kind: String, expectedSize: Int)
        case integerOverflow(offset: UInt)
    }

    private enum Endianess {
        case big
        case little
    }

    private static let magic = "cook".data(using: .ascii)!
    private static let pageHeader = Data([0x00, 0x00, 0x01, 0x00])
    private static let pageFooter = Data([0x00, 0x00, 0x00, 0x00])

    private let data: Data
    private var offset: UInt = 0
    private var currentPageOffset: UInt = 0
    private var currentCookieOffset: UInt = 0
    private var cookies: [Cookie] = []

    static func parse(_ data: Data) throws -> [Cookie] {
        var parser = BinaryCookiesParser(data)
        try parser.parse()
        return parser.cookies
    }

    private init(_ data: Data) {
        self.data = data
    }

    private mutating func parse() throws {
        let magic = try readData(size: 4, kind: "file signature")
        guard magic == Self.magic else {
            throw ParsingError.invalidData(offset: offset - 4, kind: "file signature")
        }

        let numberOfPages = try readUInt(
            ofType: UInt32.self, endianess: .big, kind: "number of pages")

        var pageSizes: [UInt] = []
        for _ in 0..<numberOfPages {
            let pageSize = try readUInt(
                ofType: UInt32.self, endianess: .big, kind: "page size")
            pageSizes.append(pageSize)
        }

        for pageSize in pageSizes {
            try parsePage(endOffset: offset + UInt(pageSize))
        }
    }

    private mutating func parsePage(endOffset: UInt) throws {
        currentPageOffset = offset

        let header = try readData(size: 4, kind: "page header")
        guard header == Self.pageHeader else {
            throw ParsingError.invalidData(offset: offset - 4, kind: "page header")
        }

        let numberOfCookies = try readUInt(
            ofType: UInt32.self, endianess: .little, kind: "number of cookies")

        // NOTE: Cookie offset is relative to the start of the page.
        var cookieOffsets: [UInt] = []
        for _ in 0..<numberOfCookies {
            let cookieOffset = try readUInt(
                ofType: UInt32.self, endianess: .little, kind: "cookie offset")
            cookieOffsets.append(cookieOffset)
        }

        let footer = try readData(size: 4, kind: "page footer")
        guard footer == Self.pageFooter else {
            throw ParsingError.invalidData(offset: offset - 4, kind: "page footer")
        }

        for cookieOffset in cookieOffsets {
            try parseCookie(relativeStartOffset: cookieOffset)
        }

        guard offset == endOffset else {
            throw ParsingError.invalidData(offset: offset - 4, kind: "page boundary")
        }
    }

    private mutating func parseCookie(
        relativeStartOffset: UInt
    ) throws {
        let startOffset = try addUInt(currentPageOffset, relativeStartOffset)
        guard startOffset == offset else {
            throw ParsingError.invalidData(offset: offset, kind: "cookie start offset")
        }

        currentCookieOffset = startOffset

        let size = try readUInt(ofType: UInt32.self, endianess: .little, kind: "cookie size")
        let version = try readUInt(ofType: UInt32.self, endianess: .little, kind: "cookie version")
        let flags = try readUInt(ofType: UInt32.self, endianess: .little, kind: "cookie flags")
        let hasPort = try readUInt(ofType: UInt32.self, endianess: .little, kind: "cookie has port")

        // NOTE: Following offsets are relative to the start of the cookie.
        let domainOffset = try readUInt(
            ofType: UInt32.self, endianess: .little, kind: "cookie domain offset")
        let nameOffset = try readUInt(
            ofType: UInt32.self, endianess: .little, kind: "cookie name offset")
        let pathOffset = try readUInt(
            ofType: UInt32.self, endianess: .little, kind: "cookie path offset")
        let valueOffset = try readUInt(
            ofType: UInt32.self, endianess: .little, kind: "cookie value offset")
        let commentOffset = try readUInt(
            ofType: UInt32.self, endianess: .little, kind: "cookie comment offset")
        let commentURLOffset = try readUInt(
            ofType: UInt32.self, endianess: .little, kind: "cookie comment url offset")

        let expirationSeconds = try readDouble(endianess: .little, kind: "cookie expiration date")
        let expiresDate =
            expirationSeconds > 0 ? Date(timeIntervalSinceReferenceDate: expirationSeconds) : nil
        let _ = try readDouble(endianess: .little, kind: "cookie creation date")

        var portList: [UInt] = []
        if hasPort == 1 {
            portList.append(
                try readUInt(ofType: UInt16.self, endianess: .little, kind: "cookie port"))
        }

        let comment: String?
        if commentOffset > 0 {
            try ensureCookieFieldAlignment(nextFieldOffset: commentOffset)
            comment = try readCString(kind: "cookie comment")
        } else {
            comment = nil
        }

        let commentURL: String?
        if commentURLOffset > 0 {
            try ensureCookieFieldAlignment(
                nextFieldOffset: commentURLOffset)
            commentURL = try readCString(kind: "cookie comment url")
        } else {
            commentURL = nil
        }

        try ensureCookieFieldAlignment(nextFieldOffset: domainOffset)
        let domain = try readCString(kind: "cookie domain")
        try ensureCookieFieldAlignment(nextFieldOffset: nameOffset)
        let name = try readCString(kind: "cookie name")
        try ensureCookieFieldAlignment(nextFieldOffset: pathOffset)
        let path = try readCString(kind: "cookie path")
        try ensureCookieFieldAlignment(nextFieldOffset: valueOffset)
        let value = try readCString(kind: "cookie value")

        // Skip trailing binary plist if any.
        offset = try addUInt(startOffset, size)

        let cookie = Cookie(
            version: version,
            name: name,
            value: value,
            domain: domain,
            path: path,
            portList: portList,
            expiresDate: expiresDate,
            flags: flags,
            comment: comment,
            commentURL: commentURL
        )
        cookies.append(cookie)
    }

    private func ensureCookieFieldAlignment(nextFieldOffset: UInt)
        throws
    {
        let expectedOffset = try addUInt(currentCookieOffset, nextFieldOffset)
        guard offset == expectedOffset else {
            throw ParsingError.invalidData(offset: offset, kind: "cookie field alignment")
        }
    }

    private mutating func readData(size: Int, kind: String) throws -> Data {
        assert(size > 0)

        let (endOffset, overflow) = offset.addingReportingOverflow(UInt(size))
        guard !overflow, endOffset <= data.count else {
            throw ParsingError.insufficientData(
                offset: offset, kind: kind, expectedSize: size)
        }

        let result = data[offset..<endOffset]
        offset = endOffset
        return result
    }

    private mutating func readUInt<T: UnsignedInteger & FixedWidthInteger>(
        ofType type: T.Type, endianess: Endianess, kind: String
    ) throws -> UInt {
        assert(T().bitWidth <= UInt.bitWidth)

        let uInt: T = try readData(size: MemoryLayout<T>.size, kind: kind).withUnsafeBytes {
            $0.loadUnaligned(as: type)
        }

        switch endianess {
        case .big:
            return UInt(T(bigEndian: uInt))
        case .little:
            return UInt(T(littleEndian: uInt))
        }
    }

    private mutating func readDouble(endianess: Endianess, kind: String)
        throws -> Double
    {
        let uInt = try readData(size: MemoryLayout<UInt64>.size, kind: kind).withUnsafeBytes {
            $0.loadUnaligned(as: UInt64.self)
        }

        switch endianess {
        case .big:
            return Double(bitPattern: UInt64(bigEndian: uInt))
        case .little:
            return Double(bitPattern: UInt64(littleEndian: uInt))
        }
    }

    private mutating func readCString(kind: String) throws -> String {
        guard let endOffset = data[offset...].firstIndex(of: 0) else {
            throw ParsingError.invalidData(offset: offset, kind: kind)
        }

        guard let string = String(data: data[offset..<UInt(endOffset)], encoding: .utf8) else {
            throw ParsingError.invalidData(offset: offset, kind: kind)
        }

        offset = try addUInt(UInt(endOffset), 1)
        return string
    }

    private func addUInt(_ lhs: UInt, _ rhs: UInt) throws -> UInt {
        let (result, overflow) = lhs.addingReportingOverflow(rhs)
        if overflow {
            throw ParsingError.integerOverflow(offset: offset)
        }
        return result
    }
}
