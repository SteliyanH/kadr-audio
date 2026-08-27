# Changelog

All notable changes to KadrAudio will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/), and this project adheres to [Semantic Versioning](https://semver.org/).

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
