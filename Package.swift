// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BrowserApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "BrowserApp",
            targets: ["BrowserApp"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BrowserApp",
            dependencies: [],
            path: "App/Sources"
        )
    ]
)