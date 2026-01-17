// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-effects",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
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
        .package(path: "../../swift-primitives/swift-effect-primitives"),
        .package(path: "../../swift-primitives/swift-dependency-primitives"),
        .package(path: "../../swift-primitives/swift-async-primitives"),
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
            ]
        ),
        .target(
            name: "Effects Testing",
            dependencies: [
                "Effects",
                .product(name: "Async Primitives", package: "swift-async-primitives"),
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
                "Effects Testing",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
