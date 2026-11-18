// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    // "KadrAudio", not the repository's "kadr-audio", because Xcode names the
    // only scheme of a one-product package after the package. The Swift Package
    // Index builds documentation with `xcodebuild docbuild -scheme <target>`, so
    // under the old name it asked for a `KadrAudio` scheme that did not exist and
    // no documentation was ever published. Every sibling package already matches
    // its product name. Dependents are unaffected: `.product(package:)` names the
    // package by its URL, which has not changed.
    name: "KadrAudio",
    // macOS is declared even though MediaPlayer and AVAudioSession are not
    // available there, and that surface is `#if os(iOS) || os(visionOS)`-guarded
    // to match. Two reasons: kadr itself requires macOS 14, so omitting the
    // platform makes the package unresolvable against it on a Mac; and
    // `swift test` runs on macOS, so an iOS-only package cannot be tested in CI
    // at all.
    //
    // tvOS is not declared, but that does not exclude it: `platforms` only sets
    // minimum versions, and an undeclared platform builds at SwiftPM's default.
    // It gets the same platform-neutral subset as macOS and is not supported.
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
        // The README's code blocks, copied here by Tools/readme-snippets.sh so
        // they compile. They called a `Video.music(_:)` that kadr has never had,
        // because nothing checked them. Not a product: nothing depends on it.
        .target(
            name: "KadrAudioExamples",
            dependencies: [
                "KadrAudio",
                .product(name: "Kadr", package: "kadr"),
            ],
            path: "Examples",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "KadrAudioTests",
            dependencies: ["KadrAudio"]
        ),
    ]
)
