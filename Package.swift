// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LocusClean",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "LocusCleanCore", targets: ["LocusCleanCore"]),
    ],
    targets: [
        .target(name: "LocusCleanCore", path: "Sources/LocusCleanCore"),
        .testTarget(name: "LocusCleanCoreTests", dependencies: ["LocusCleanCore"], path: "Tests/LocusCleanCoreTests"),
    ]
)
