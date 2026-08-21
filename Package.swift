// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Blink1",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "Blink1", targets: ["Blink1"]),
        .library(name: "Blink1Control", targets: ["Blink1Control"]),
        .executable(name: "blink1", targets: ["Blink1CLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(name: "Blink1"),
        // The wire vocabulary between the app that owns the device and everything that reports status.
        .target(name: "Blink1Control"),
        .executableTarget(
            name: "Blink1CLI",
            dependencies: [
                "Blink1",
                "Blink1Control",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "Blink1Tests", dependencies: ["Blink1"]),
    ]
)
