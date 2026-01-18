// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-effects-tests",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    dependencies: [
        // Parent package
        .package(path: "../"),
        // Testing framework
        .package(path: "../../swift-testing"),
        // Test primitives (for test utilities)
        .package(path: "../../../swift-primitives/swift-test-primitives"),
        .package(path: "../../../swift-primitives/swift-async-primitives"),
    ],
    targets: [
        .testTarget(
            name: "Effects Tests",
            dependencies: [
                .product(name: "Effects", package: "swift-effects"),
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Test Primitives", package: "swift-test-primitives"),
            ],
            path: "Sources/Effects Tests"
        ),
        .testTarget(
            name: "Effects Built-in Tests",
            dependencies: [
                .product(name: "Effects", package: "swift-effects"),
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Test Primitives", package: "swift-test-primitives"),
                .product(name: "Async Primitives", package: "swift-async-primitives"),
            ],
            path: "Sources/Effects Built-in Tests"
        ),
        .testTarget(
            name: "Effects Testing Tests",
            dependencies: [
                .product(name: "Effects", package: "swift-effects"),
                .product(name: "Testing", package: "swift-testing"),
                .product(name: "Test Primitives", package: "swift-test-primitives"),
            ],
            path: "Sources/Effects Testing Tests"
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
