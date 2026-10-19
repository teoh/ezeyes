// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EzEyes",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "EzEyes", targets: ["EzEyes"])
    ],
    targets: [
        .target(
            name: "NightShiftBridge",
            path: "Sources/NightShiftBridge",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("Foundation")]
        ),
        .executableTarget(
            name: "EzEyes",
            dependencies: ["NightShiftBridge"],
            path: "Sources/EzEyes",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
