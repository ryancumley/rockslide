// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "rockslide",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(
            name: "rockslide",
            targets: ["rockslide"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "rockslide",
            dependencies: []),
    ]
)
