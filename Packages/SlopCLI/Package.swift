// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlopCLI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SlopCLI", targets: ["SlopCLI"]),
    ],
    dependencies: [
        .package(path: "../SlopIPC"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "SlopCLI",
            dependencies: [
                .product(name: "SlopIPC", package: "SlopIPC"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SlopCLITests",
            dependencies: ["SlopCLI"]
        ),
    ]
)
