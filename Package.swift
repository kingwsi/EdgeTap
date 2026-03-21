// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "EdgeTap",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "EdgeTapCore",
            targets: ["EdgeTapCore"]
        ),
        .executable(
            name: "EdgeTapApp",
            targets: ["EdgeTapApp"]
        ),
    ],
    targets: [
        .target(
            name: "EdgeTapCore"
        ),
        .target(
            name: "CMultitouchBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("dl"),
            ]
        ),
        .executableTarget(
            name: "EdgeTapApp",
            dependencies: [
                "EdgeTapCore",
                "CMultitouchBridge",
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
    ]
)
