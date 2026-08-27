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

## Audio that is actually audible

**A fresh iOS app gets the `.soloAmbient` session category, which obeys the ring/silent switch.** So a user with a muted phone opens a video editor and the preview is silent, with nothing on screen explaining why. Nothing in the kadr family configured this before v0.2, which means every consumer had the bug.

```swift
try AudioSession.configure(.preview)   // audible with the phone muted
try AudioSession.activate()            // takes audio focus — do this when the preview appears
// ...
try AudioSession.deactivate()          // lets the user's music resume
```

Configuration and activation are separate calls on purpose. Activation takes audio focus from other apps, so a host that activates at launch silences the user's music for as long as the app is open.

Interruptions are a stream:

```swift
for await interruption in AudioSession.interruptions {
    switch interruption {
    case .began: player.pause()
    case .ended(let shouldResume) where shouldResume: player.play()
    case .ended: break
    }
}
```

`shouldResume` is the system's opinion, not a formality. Ignoring it is how an app ends up talking over a phone call.

## Voiceover

```swift
let recorder = VoiceoverRecorder()
guard await VoiceoverRecorder.requestAuthorization() else { return }

try recorder.start()                     // session configured, latency measured
// ... the performer speaks against the preview ...
let take = try recorder.stop()

video = video.audio { take.audioTrack(startingAt: previewTime) }
```

**The latency correction is the point.** A voiceover is performed against playback: the performer reacts to audio that already left the device late, and their voice arrives at the input late again. Both delays land in the recording.

Wired headphones add a couple of milliseconds. **Bluetooth adds 150–200 ms** — several frames at 30 fps, and unmistakable on a lip-sync. `audioTrack(startingAt:)` places the take earlier by exactly the latency measured when recording began.

Measured at `start()` rather than at construction, because plugging in AirPods between the two changes the answer by two orders of magnitude.

**Required entitlement:** `NSMicrophoneUsageDescription`.

## Loudness

Every social platform normalises on upload — Instagram, TikTok and YouTube all target roughly **−14 LUFS**. A composition mixed by ear is re-levelled *after* publishing, usually downward and unevenly across clips mixed at different times. Measuring first is the only way to control what the platform does rather than discover it.

```swift
let measured = Loudness.integrated(samples: samples, sampleRate: 48_000, channels: 2)
let track = AudioTrack(url: musicURL).normalized(from: measured, to: .social)
```

Implemented per **ITU-R BS.1770-4**: K-weighting, 400 ms blocks at 75% overlap, absolute gate at −70 LUFS and a relative gate 10 LU below.

`Loudness.integrated` takes samples rather than a URL on purpose — it is pure arithmetic, so it is testable anywhere, and the caller decides when to pay for reading a five-minute file.

**Gain above 1.0 raises peaks as well as loudness**, and nothing here limits them, so a very quiet source pushed to −14 LUFS may clip. Platforms normalise downward far more often than upward, so the common direction is the safe one.

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
