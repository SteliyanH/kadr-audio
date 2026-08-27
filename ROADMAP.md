# KadrAudio Roadmap

## v0.1.0 — Music-library resolution ✓ shipped

`MPMediaItem` → kadr `AudioTrack`, with the DRM reality handled explicitly rather
than left for a consumer to discover in the field.

## v0.2.0 — Loudness normalisation *(planned)*

LUFS measurement and a normalising modifier. Social platforms normalise on upload
— Instagram, TikTok and YouTube all target around −14 LUFS — so a composition
mixed by ear is re-levelled after publishing, usually downward and unevenly
across clips. Measuring and normalising before export is the only way to control
what the platform does.

Belongs here rather than in core for the same reason as everything else in this
package: it is analysis against an external target, not composition.

## v0.3.0 — Effects *(candidate)*

EQ, compression and reverb via `AVAudioEngine`. Genuinely useful, and genuinely
not AVFoundation composition — which is the test for whether something belongs in
this package.

## v1.0.0 — Production Ready

Tracks kadr v1.0.

- API stability commitment — no breaking change without a major version bump.
- Supported kadr range stated explicitly and kept current.
- DocC catalogue considered complete for the shipped surface.

> **This package will have had the least time in anyone's hands of the five.**
> Its 1.0 section should say plainly which parts are settled and which are
> provisional, rather than claiming the confidence of an engine with twenty
> minors behind it.

## Explicit non-goals

- **Speech recognition and auto-captions.** Those are kadr-pro features, and they
  belong to a commercial tier rather than to an adapter.
- **Anything AVFoundation can already do.** Per-clip volume, waveform extraction
  and audio-only export are kadr core's job. If this package ever holds only
  AVFoundation work, it has stopped being a package and become a fragmentation of
  core.

## Contributing

Open an issue here for music-library edge cases, or on
[kadr](https://github.com/SteliyanH/kadr) for upstream audio-surface requests.
