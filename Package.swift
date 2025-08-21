// swift-tools-version: 6.2
// SPDX-License-Identifier: MIT

import PackageDescription

let package = Package(
    name: "safariknife",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1")
    ],
    targets: [
        .executableTarget(
            name: "safariknife",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
