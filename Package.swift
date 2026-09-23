// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FocusList",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "FocusList", path: "Sources/FocusList")
    ]
)
