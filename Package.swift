// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RAMMenubar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "RAMMenubar",
            path: "Sources/RAMMenubar"
        )
    ]
)
