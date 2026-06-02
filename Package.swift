// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "XcodeBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "XcodeBar", targets: ["XcodeBar"])
    ],
    targets: [
        .executableTarget(
            name: "XcodeBar",
            path: "Sources/XcodeBar"
        )
    ]
)
