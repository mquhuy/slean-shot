// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SleanShot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SleanShotCore",
            targets: ["SleanShotCore"]
        ),
        .executable(
            name: "SleanShotApp",
            targets: ["SleanShotApp"]
        ),
        .executable(
            name: "SleanShotCoreTestRunner",
            targets: ["SleanShotCoreTestRunner"]
        )
    ],
    targets: [
        .target(
            name: "SleanShotCore"
        ),
        .executableTarget(
            name: "SleanShotApp",
            dependencies: ["SleanShotCore"]
        ),
        .executableTarget(
            name: "SleanShotCoreTestRunner",
            dependencies: ["SleanShotCore"]
        )
    ]
)
