// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuType",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MenuType",
            path: "Sources/MenuType"
        )
    ]
)
