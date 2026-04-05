// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlopTemplates",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SlopTemplates", targets: ["SlopTemplates"]),
    ],
    dependencies: [
        .package(path: "../SlopKit"),
        .package(url: "https://github.com/krzyzanowskim/STTextView.git", from: "2.3.5"),
        .package(url: "https://github.com/swiftcsv/SwiftCSV.git", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "SlopTemplates",
            dependencies: [
                .product(name: "SlopKit", package: "SlopKit"),
                .product(name: "STTextView", package: "STTextView"),
                .product(name: "SwiftCSV", package: "SwiftCSV"),
            ]
        ),
        .testTarget(
            name: "SlopTemplatesTests",
            dependencies: ["SlopTemplates"]
        ),
    ]
)
