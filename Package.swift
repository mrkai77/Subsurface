// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Subsurface",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Subsurface",
            targets: ["Subsurface"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SenpaiHunters/Scribe", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Subsurface",
            dependencies: [
                .product(name: "Scribe", package: "Scribe")
            ]
        )
    ]
)
