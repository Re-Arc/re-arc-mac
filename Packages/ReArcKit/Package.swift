// swift-tools-version: 6.0
import PackageDescription

let composableArchitecture = Target.Dependency.product(
    name: "ComposableArchitecture",
    package: "swift-composable-architecture"
)

let package = Package(
    name: "ReArcKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppShell", targets: ["AppShell"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    ],
    targets: [
        // Listed from the app entry point down the dependency graph.
        .target(
            name: "AppShell",
            dependencies: ["AppFeature", "BrowserEngine", "ReArcUI", composableArchitecture]
        ),
        .target(
            name: "AppFeature",
            dependencies: ["ReArcFoundation", composableArchitecture]
        ),
        .target(
            name: "BrowserEngine",
            dependencies: ["ReArcFoundation"]
        ),
        .target(name: "ReArcUI"),
        .target(name: "ReArcFoundation"),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: ["AppFeature", composableArchitecture]
        ),
    ]
)
