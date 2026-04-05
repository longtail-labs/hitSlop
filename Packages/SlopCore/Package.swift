// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlopCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SlopUI", targets: ["SlopUI"]),
        .library(name: "SlopAI", targets: ["SlopAI"]),
    ],
    dependencies: [
        .package(path: "../SlopKit"),
        .package(path: "../SlopTemplates"),
        .package(path: "../SlopIPC"),
        .package(url: "https://github.com/tomsci/LuaSwift.git", from: "1.0.0"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.11.0"),
    ],
    targets: [
        .target(
            name: "SlopAI",
            dependencies: [
                .product(name: "SlopKit", package: "SlopKit"),
                .product(name: "FirebaseAILogic", package: "firebase-ios-sdk"),
            ]
        ),
        .target(
            name: "SlopUI",
            dependencies: [
                .product(name: "SlopKit", package: "SlopKit"),
                .product(name: "SlopIPC", package: "SlopIPC"),
                "SlopAI",
                .product(name: "Lua", package: "LuaSwift"),
                .product(name: "SlopTemplates", package: "SlopTemplates"),
            ],
            resources: [
                .copy("Resources/templates"),
                .copy("Resources/themes"),
                .copy("Resources/skill"),
                .copy("Resources/skins"),
            ]
        ),
        .executableTarget(name: "SkinGen"),
        .testTarget(
            name: "SlopUITests",
            dependencies: [
                "SlopUI",
                "SlopAI",
            ]
        ),
    ]
)
