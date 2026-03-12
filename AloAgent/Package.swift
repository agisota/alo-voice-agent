// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AloAgent",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/livekit/client-sdk-swift", from: "2.2.0"),
        .package(url: "https://github.com/livekit/components-swift", from: "0.1.6"),
    ],
    targets: [
        .executableTarget(
            name: "AloAgent",
            dependencies: [
                .product(name: "LiveKit", package: "client-sdk-swift"),
                .product(name: "LiveKitComponents", package: "components-swift"),
            ],
            path: "Sources"
        ),
    ]
)
