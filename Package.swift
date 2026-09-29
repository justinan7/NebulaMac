// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NebulaMac",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "NebulaMacCore",
            path: "NebulaMacCore"
        ),
        .executableTarget(
            name: "NebulaMac",
            dependencies: ["NebulaMacCore"],
            path: "NebulaMac",
            exclude: ["Info.plist"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "NebulaMacCoreTests",
            dependencies: ["NebulaMacCore"],
            path: "Tests/NebulaMacCoreTests"
        )
    ]
)
