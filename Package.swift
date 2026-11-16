// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CSSign",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // xtool expects exactly one library product: the app itself.
        .library(name: "CSSign", targets: ["CSSign"]),
    ],
    targets: [
        .target(
            name: "CSSign",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
