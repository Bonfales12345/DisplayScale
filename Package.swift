// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DisplayScale",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DisplayScale", targets: ["DisplayScaleApp"])
    ],
    targets: [
        .executableTarget(name: "DisplayScaleApp")
    ]
)
