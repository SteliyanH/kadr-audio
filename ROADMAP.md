# KadrAudio Roadmap

## v0.1.0 — Music-library resolution ✓ shipped

`MPMediaItem` → kadr `AudioTrack`, with the DRM reality handled explicitly rather
than left for a consumer to discover in the field.

## v0.2.0 — Audio session management ✓ shipped

**The gap this closes exists today, in every consumer.** No repository in the
family touches `AVAudioSession` — not kadr, not kadr-ui, not the reference app.
So `VideoPreview` plays under whatever session the host happens to be in, which
for a fresh app is `.soloAmbient`:

- **Preview audio is silenced by the ring/silent switch.** For a video editor
  that is a defect, not a preference: the user mutes their phone, opens the
  editor, and the preview is silent with nothing explaining why.
- **No interruption handling.** A phone call or Siri stops playback and nothing
  resumes it.
- **No control over whether starting a preview stops the user's music.**

Scope: a category/activation helper with sensible defaults for preview and for
recording, interruption and route-change handling, and enough surface for a host
that wants to make its own choices.

Belongs here rather than in core because `AVAudioSession` is iOS-only session
management, not AVFoundation composition. Unambiguously free: it wraps a public
Apple API and is tedious rather than clever.

## v0.3.0 — Voiceover recording *(planned)*

`AVAudioRecorder` / `AVAudioEngine` capture, landing at a timeline offset. The
capability is free from Apple; the work is integration — recording while the
preview plays, and getting the result to line up.

Includes **Bluetooth latency compensation**. AirPods add roughly 150–200 ms, so a
voiceover recorded against playback lands late by default. Hard, unglamorous, and
nobody would pay for "the audio is not broken" — which is exactly why it is free
and exactly why it has to be handled here rather than left to each consumer.

Depends on v0.2: recording needs the session configured correctly regardless.

## v0.4.0 — Loudness normalisation *(planned)*

LUFS measurement and a normalising modifier. Social platforms normalise on upload
— Instagram, TikTok and YouTube all target around −14 LUFS — so a composition
mixed by ear is re-levelled after publishing, usually downward and unevenly
across clips.

**Moved back from v0.2 deliberately.** It is the more interesting piece of work
and the less needed one: session handling fixes a live defect, this improves an
output that already plays.

Worth recording that this sits on the free side by judgement rather than by rule.
No Apple API measures LUFS, which is the profile of a paid feature — but
platform-normalisation correctness is what makes a free tier credible rather than
a demo.

## Smaller additions *(candidates)*

All free by the same test — each wraps something Apple already gives away:

- **Music metadata for attribution** — artist and title from `MPMediaItem` into a
  `TextOverlay`, for the credit line platforms expect.
- **Typed audio-file import** — the reference app hand-rolls `fileImporter` with
  a guessed content-type list and validates nothing. A helper that confirms a
  file actually decodes before it reaches a composition.
- **Route awareness** — headphones against speaker, mainly so recording does not
  capture playback.

## Deliberately not free

These have no Apple equivalent, which is the profile of a paid feature rather
than a free one. Listed here so the boundary is written down rather than
rediscovered:

- **Beat and BPM detection.** "Cut to the beat" is the social-video editing
  idiom and no Apple API does it. High perceived value, real algorithm.
- **Speech-triggered auto-ducking.** Core already has manual ducking; making it
  automatic is the "smart" version, the same shape as smart crop on the pro list.

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
