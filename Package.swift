// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexMeter",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CodexMeter", targets: ["CodexMeter"]),
    ],
    targets: [
        .target(name: "CodexMeterCore"),
        .executableTarget(
            name: "CodexMeter",
            dependencies: ["CodexMeterCore"]
        ),
        .executableTarget(
            name: "CodexMeterCoreTests",
            dependencies: ["CodexMeterCore"],
            path: "Tests/CodexMeterCoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
