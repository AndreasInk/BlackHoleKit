// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BlackHoleKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "BlackHoleKit",
            targets: ["BlackHoleKit"]
        )
    ],
    targets: [
        .target(
            name: "BlackHoleKit",
            exclude: ["BlackHoleKit.docc"]
        ),
        .testTarget(
            name: "BlackHoleKitTests",
            dependencies: ["BlackHoleKit"]
        )
    ]
)
