// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PokerNowHud",
    products: [
        .executable(name: "pnhud", targets: ["PokerNowHud"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.0.1"),
        .package(name: "SocketIO", url: "https://github.com/socketio/socket.io-client-swift", .upToNextMinor(from: "15.0.0")),
        .package(url: "https://github.com/swiftcsv/SwiftCSV", from: "0.0.1"),
        .package(url: "https://github.com/scottrhoyt/SwiftyTextTable.git", from: "0.5.0")
    ],
    targets: [
        .target(name: "PokerNowHud", dependencies: [
            "SocketIO",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            .product(name: "SwiftCSV", package: "SwiftCSV"),
            "SwiftyTextTable"
        ])
    ]
)
