// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "rockslide",
    platforms: [.macOS(.v12), .iOS(.v15)],
    products: [
        .library(name: "routt", targets: ["routt"]),
        .library(name: "laramide", targets: ["laramide"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "routt",
            dependencies: [],
            path: "./Sources/routt"
        ),
        .target(
            name: "laramide",
            dependencies: [],
            path: "./Sources/laramide"
        ),
    ]
)
