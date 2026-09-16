// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocusSweep",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LocusSweepCore", targets: ["LocusSweepCore"]),
    ],
    targets: [
        .target(name: "LocusSweepCore", path: "Sources/LocusSweepCore"),
        .testTarget(name: "LocusSweepCoreTests", dependencies: ["LocusSweepCore"], path: "Tests/LocusSweepCoreTests"),
    ]
)
