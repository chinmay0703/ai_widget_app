// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FloatingAI",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "FloatingAI",
            path: "Sources/FloatingAI"
        )
    ]
)
