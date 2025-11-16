// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SwiftTOON",
    platforms: [
        .macOS(.v13)
    ],

    products: [
        .library(
            name: "TOONCore",
            targets: ["TOONCore"]
        ),
        .library(
            name: "TOONCodable",
            targets: ["TOONCodable"]
        ),
        .executable(
            name: "toon-swift",
            targets: ["TOONCLI"]
        ),
        .executable(
            name: "TOONBenchmarks",
            targets: ["TOONBenchmarksRunner"]
        ),
        .library(
            name: "TOONBenchmarksCore",
            targets: ["TOONBenchmarks"]
        ),
    ],
    targets: [
        .target(
            name: "TOONCore",
            path: "Sources/TOONCore"
        ),
        .target(
            name: "TOONCodable",
            dependencies: ["TOONCore"],
            path: "Sources/TOONCodable"
        ),
        .executableTarget(
            name: "TOONCLI",
            dependencies: ["TOONCodable", "TOONCore", "TOONBenchmarks"],
            path: "Sources/TOONCLI"
        ),
        .target(
            name: "TOONBenchmarks",
            dependencies: [
                "TOONCore",
                "TOONCodable"
            ],
            path: "Sources/TOONBenchmarks"
        ),
        .executableTarget(
            name: "TOONBenchmarksRunner",
            dependencies: ["TOONBenchmarks"],
            path: "Sources/TOONBenchmarksRunner"
        ),
        .executableTarget(
            name: "CaptureEncodeRepresentations",
            dependencies: ["TOONCodable", "TOONCore"],
            path: "Scripts/CaptureEncodeRepresentations"
        ),
        .target(
            name: "SwiftTOONDocC",
            path: "Sources/SwiftTOONDocC",
            resources: [
                .process("SwiftTOON.docc")
            ]
        ),
        .testTarget(
            name: "TOONCoreTests",
            dependencies: ["TOONCore"],
            path: "Tests/TOONCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "TOONCodableTests",
            dependencies: ["TOONCodable"],
            path: "Tests/TOONCodableTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "TOONCLITests",
            dependencies: ["TOONCLI"],
            path: "Tests/TOONCLITests",
            resources: [
                .process("Snapshots")
            ]
        ),
        .testTarget(
            name: "ConformanceTests",
            dependencies: ["TOONCodable"],
            path: "Tests/ConformanceTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
        .testTarget(
            name: "BenchmarkHarnessTests",
            dependencies: ["TOONBenchmarks"],
            path: "Tests/BenchmarkHarnessTests"
        ),
        .testTarget(
            name: "TOONBenchmarksTests",
            dependencies: ["TOONBenchmarks"],
            path: "Tests/TOONBenchmarksTests"
        ),
    ]
)
