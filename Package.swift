// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PlainSign",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // xtool expects exactly one library product: the app itself.
        .library(name: "PlainSign", targets: ["PlainSign"]),
    ],
    targets: [
        .target(
            name: "PlainSign",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
