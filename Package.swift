// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HappinessPulse",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(
            name: "HappinessPulse",
            targets: ["HappinessPulse"]
        )
    ],
    targets: [
        .executableTarget(
            name: "HappinessPulse",
            path: "HappinessPulse"
        ),
        .testTarget(
            name: "HappinessPulseTests",
            dependencies: ["HappinessPulse"],
            path: "Tests/HappinessPulseTests"
        )
    ]
)
