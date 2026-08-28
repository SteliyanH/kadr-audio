// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "kadr-audio",
    // macOS is declared even though MediaPlayer is not available there, and the
    // MediaPlayer surface is `#if canImport`-guarded to match. Two reasons: kadr
    // itself requires macOS 14, so omitting the platform makes the package
    // unresolvable against it on a Mac; and `swift test` runs on macOS, so an
    // iOS-only package cannot be tested in CI at all.
    //
    // tvOS is excluded: `MPMediaPickerController` does not exist there, and unlike
    // macOS there is no reason to pretend otherwise.
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(name: "KadrAudio", targets: ["KadrAudio"]),
    ],
    dependencies: [
        .package(url: "https://github.com/SteliyanH/kadr.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "KadrAudio",
            dependencies: [
                .product(name: "Kadr", package: "kadr"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "KadrAudioTests",
            dependencies: ["KadrAudio"]
        ),
    ]
)
