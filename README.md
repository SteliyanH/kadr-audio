# KadrAudio

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2017+%20|%20visionOS%201+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)
[![Sponsor](https://img.shields.io/badge/Sponsor-Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/steliyanh)

**Music-library integration for [Kadr](https://github.com/SteliyanH/kadr) — resolve the user's own music into kadr `AudioTrack`s, and say something useful about the large part of a library that cannot be used.**

KadrAudio bridges `MediaPlayer` to kadr's audio surface. It lives in its own package because kadr core is AVFoundation-only by policy — the same reason `Photos` lives in [kadr-photos](https://github.com/SteliyanH/kadr-photos). A package is justified by a dependency, not by a topic.

## The thing worth knowing first

**Most of a typical music library cannot be exported into a video.** Apple Music tracks are DRM-protected: `MPMediaItem.assetURL` is `nil` for anything from a subscription, and no API turns one into a file. Only music the user owns — purchased, or imported themselves — exposes a URL.

A consumer that does not know this ships a picker where nearly everything the user taps fails, with nothing useful said. This package makes that case explicit in two ways:

```swift
// Offer only what will actually work
let usable = try MusicLibrary.usableSongs()

// Or resolve and handle the refusal properly
do {
    let track = try MusicLibrary.audioTrack(for: picked)
    video = video.music(track.volume(0.4).ducking(0.2))
} catch let error as MusicLibraryError {
    // "Songs from Apple Music are protected and can't be exported.
    //  Music you own or imported yourself will work."
    show(error.localizedDescription, error.recoverySuggestion)
}
```

The error text names the reason rather than suggesting a retry, because retrying with another Apple Music track fails identically.

## Quick Start

```swift
.package(url: "https://github.com/SteliyanH/kadr-audio.git", .upToNextMinor(from: "0.1.0")),
```

Add `KadrAudio` to your target's dependencies. `Kadr` is pulled in transitively — 0.1.x resolves `>=0.20.0, <0.21.0`.

> **Use `.upToNextMinor`, not `from:`.** `from:` means `.upToNextMajor`, and SwiftPM does not special-case `0.x` — so `from: "0.1.0"` would accept every future 0.x release including breaking ones.

**Required entitlement:** `NSAppleMusicUsageDescription` in your app's Info.plist. Without it, requesting authorization terminates the app.

## Platforms

iOS 17+ and visionOS 1+. macOS is declared in the manifest so the package resolves against kadr and can be tested in CI, but the MediaPlayer surface is unavailable there. tvOS is excluded outright — `MPMediaPickerController` does not exist.

## Roadmap

See [ROADMAP.md](ROADMAP.md). v0.1 is music-library resolution. Loudness normalisation (LUFS) and AVAudioEngine effects are the next candidates — both belong here for the same reason, and neither is in core.

## License

Apache-2.0. See [LICENSE](LICENSE).

Contributions are accepted under the [Contributor License Agreement](CLA.md), which is signed once and covers all future contributions. It does not transfer ownership — you keep the copyright in your work.
