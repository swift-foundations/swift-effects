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
            url: "https://github.com/swift-primitives/swift-effect-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-dependency-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-witness-primitives.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-primitives/swift-async-primitives.git",
            branch: "main"
        ),
        .package(url: "https://github.com/swift-foundations/swift-clocks.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Effects",
            dependencies: [
                .product(name: "Effect Primitives", package: "swift-effect-primitives"),
                .product(name: "Dependency Primitives", package: "swift-dependency-primitives"),
            ]
        ),
        .target(
            name: "Effects Built-in",
            dependencies: [
                "Effects",
                .product(name: "Witness Primitives", package: "swift-witness-primitives"),
            ]
        ),
        .target(
            name: "Effects Testing",
            dependencies: [
                "Effects",
                .product(name: "Async Primitives", package: "swift-async-primitives"),
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
                .product(name: "Async Primitives", package: "swift-async-primitives"),
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
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
