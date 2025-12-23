// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PodcastAssistantFeature",
    platforms: [.macOS("26.0")],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PodcastAssistantFeature",
            targets: ["PodcastAssistantFeature"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/praeclarum/SwiftIntelligence", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PodcastAssistantFeature",
            dependencies: [
                .product(name: "SwiftIntelligence", package: "SwiftIntelligence")
            ]
        ),
        .testTarget(
            name: "PodcastAssistantFeatureTests",
            dependencies: [
                "PodcastAssistantFeature"
            ]
        ),
    ]
)
