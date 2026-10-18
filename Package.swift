// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "XMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "XMac", targets: ["XMac"])
    ],
    targets: [
        .target(
            name: "XMacCore",
            path: "Sources/XMacCore"
        ),
        .executableTarget(
            name: "XMac",
            dependencies: ["XMacCore"],
            path: "Sources/XMac"
        ),
        .testTarget(
            name: "XMacTests",
            dependencies: ["XMacCore"],
            path: "Tests/XMacTests"
        )
    ]
)
