# Changelog

All notable changes to KadrAudio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-08-27

Audio session management. Closes a defect that was live in every consumer.

### Added

- **`AudioSession`** — configure, activate, deactivate, and observe interruptions.

  **The bug this fixes:** nothing in the kadr family touched `AVAudioSession`, so
  a host app got whatever session it happened to be in — `.soloAmbient` for a
  fresh app. That category obeys the ring/silent switch, so a muted phone meant a
  silent preview with nothing on screen explaining why. Video playback is expected
  to ignore that switch, which is why every video app you have used does.

  Two further consequences of having no session: an interruption stopped playback
  and nothing resumed it, and starting a preview stopped the user's music without
  anyone deciding it should.

- **`AudioSessionPolicy`** — `.preview`, `.voiceover`, `.ambient`, or a custom
  combination of input, sharing and silent-switch behaviour.

  Split from `AudioSession` deliberately. Choosing a category and options is where
  the decisions live and is worth testing; `AVAudioSession` cannot be exercised off
  a device at all. The policy is pure and available on every platform, so it has
  coverage. Applying it is a thin call that does not.

- **`AudioSession.interruptions`** — an `AsyncStream`, carrying the system's
  `shouldResume` opinion rather than discarding it. Ignoring that flag is how an
  app ends up talking over a phone call.

### Notes

- Configuration and activation are separate calls. Activation takes audio focus,
  so a host that activates at launch silences the user's music for as long as the
  app is open; one that activates when a preview appears behaves well.
- `deactivate(notifyOthers:)` defaults to `true`, which lets a paused music app
  resume. Leaving it stopped with no way back reads as the app being broken.

## [0.1.0] - 2026-08-27

First release. Music-library resolution for kadr.

### Added

- **`MusicLibrary.audioTrack(for:)`** — resolves an `MPMediaItem` into a kadr
  `AudioTrack`, or throws a `MusicLibraryError` explaining why it cannot.
- **`MusicLibrary.usableSongs()`** — the songs that can actually be exported,
  filtered by `assetURL`. Presenting the unfiltered library is the mistake this
  exists to prevent.
- **`MusicLibrary.isAuthorized` / `requestAuthorization()`** — the latter returns
  the status rather than a `Bool`, because `.denied` and `.restricted` need
  different interfaces: one is fixable in Settings, the other is not fixable by
  the user at all.
- **`MusicLibraryError` conforming to `LocalizedError`.** The wording carries the
  weight here: the failure a user hits most often is an Apple Music track, which
  is not their fault and cannot be fixed by retrying. The recovery text names the
  reason instead of suggesting they try again, because trying again with another
  subscription track fails identically.

### Notes

- **Most of a typical music library cannot be used.** Apple Music tracks are
  DRM-protected and expose no `assetURL`, and no API produces one. Only music the
  user owns is exportable. This is the single most important thing a consumer
  needs to know, so it leads the README rather than sitting in a footnote.
- macOS is declared in the manifest so the package resolves against kadr and can
  be tested in CI, but MediaPlayer's types are unavailable there and the surface
  is guarded with `#if os(iOS) || os(visionOS)` — `canImport(MediaPlayer)` is
  true on macOS and would have compiled to a wall of unavailability errors.
- tvOS is excluded outright: `MPMediaPickerController` does not exist there.
