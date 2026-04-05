// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlopIPC",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SlopIPC", targets: ["SlopIPC"]),
    ],
    targets: [
        .target(name: "SlopIPC"),
        .testTarget(
            name: "SlopIPCTests",
            dependencies: ["SlopIPC"]
        ),
    ]
)
