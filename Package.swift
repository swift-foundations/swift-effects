// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-effects",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(
            name: "Effects",
            targets: ["Effects"]
        ),
        .library(
            name: "Effects Built-in",
            targets: ["Effects Built-in"]
        ),
        .library(
            name: "Effects Testing",
            targets: ["Effects Testing"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/swift-molecules/swift-effect.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-dependency.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-witness.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-molecules/swift-async.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-compositions/swift-clocks.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Effects",
            dependencies: [
                .product(name: "Effect", package: "swift-effect"),
                .product(name: "Dependency", package: "swift-dependency"),
            ]
        ),
        .target(
            name: "Effects Built-in",
            dependencies: [
                "Effects",
                .product(name: "Witness", package: "swift-witness"),
            ]
        ),
        .target(
            name: "Effects Testing",
            dependencies: [
                "Effects",
                .product(name: "Async", package: "swift-async"),
                .product(name: "Clocks", package: "swift-clocks"),
            ]
        ),
        .testTarget(
            name: "Effects Tests",
            dependencies: [
                "Effects",
                "Effects Testing",
            ]
        ),
        .testTarget(
            name: "Effects Built-in Tests",
            dependencies: [
                "Effects Built-in",
                "Effects Testing",
                .product(name: "Async", package: "swift-async"),
            ]
        ),
        .testTarget(
            name: "Effects Testing Tests",
            dependencies: [
                "Effects Testing"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
