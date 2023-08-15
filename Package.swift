// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Database",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v14)
    ],
    products: [
        .library(name: "Database", targets: ["Database"])
    ],
    dependencies: [],
    targets: [
        .target(name: "Database", dependencies: [])
    ]
)
