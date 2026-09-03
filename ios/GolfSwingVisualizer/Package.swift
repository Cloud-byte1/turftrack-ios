// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GolfSwingVisualizer",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "GolfSwingVisualizer", targets: ["GolfSwingVisualizer"])
    ],
    targets: [
        .target(
            name: "GolfSwingVisualizer",
            path: "Sources/GolfSwingVisualizer"
        ),
        .testTarget(
            name: "GolfSwingVisualizerTests",
            dependencies: ["GolfSwingVisualizer"],
            path: "Tests/GolfSwingVisualizerTests"
        )
    ]
)
