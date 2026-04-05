// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport
import Foundation

let usePrebuiltMacros = ProcessInfo.processInfo.environment["SLOPKIT_PREBUILT_MACROS"] != nil

var deps: [Package.Dependency] = [
    .package(url: "https://github.com/danielsaidi/EmojiKit.git", from: "2.3.5")
]
if !usePrebuiltMacros {
    deps.append(.package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"))
}

let package = Package(
    name: "SlopKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SlopKit", targets: ["SlopKit"]),
    ],
    dependencies: deps,
    targets: {
        var targets: [Target] = [
            .target(
                name: "SlopKit",
                dependencies: usePrebuiltMacros
                    ? [.product(name: "EmojiKit", package: "EmojiKit")]
                    : ["SlopMacros", .product(name: "EmojiKit", package: "EmojiKit")]
            ),
        ]
        if !usePrebuiltMacros {
            targets.append(.macro(
                name: "SlopMacros",
                dependencies: [
                    .product(name: "SwiftSyntax", package: "swift-syntax"),
                    .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                    .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                ]
            ))
            targets.append(.testTarget(
                name: "SlopKitTests",
                dependencies: [
                    "SlopKit",
                    "SlopMacros",
                    .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                ],
                path: "Tests/SlopKitTests"
            ))
        }
        return targets
    }()
)
