# ``KadrAudio``

Music, voice and loudness for [Kadr](https://github.com/SteliyanH/kadr).

## Overview

KadrAudio holds the audio work kadr core deliberately does not: anything needing
a framework core refuses to link, and anything that is analysis rather than
composition.

kadr core is AVFoundation-only by policy. This package links **MediaPlayer** for
the music library and **AVFAudio** for sessions and recording, which is the same
reason `Photos` lives in kadr-photos. **A package is justified by a dependency,
not by a topic** — per-clip volume, waveform extraction and audio-only export are
core's job and stay there.

## The three things worth knowing first

**Most of a music library cannot be exported.** Apple Music tracks are
DRM-protected: ``MPMediaItem/assetURL`` is `nil` for anything from a
subscription, and no API turns one into a file. Use
``MusicLibrary/usableSongs()`` to offer only what will work.

**A fresh app silences your preview.** iOS gives an app `.soloAmbient` by
default, which obeys the ring/silent switch — so a muted phone means a silent
editor. ``AudioSession/configure(_:)`` with ``AudioSessionPolicy/preview`` fixes
it, and nothing in the kadr family did this before v0.2.

**A voiceover recorded over Bluetooth lands late.** 150–200 ms, which is several
frames at 30 fps. ``Voiceover/audioTrack(startingAt:)`` corrects it using the
latency measured when recording began.

## Topics

### Music library

- ``MusicLibrary``
- ``MusicLibraryError``
- ``MusicAttribution``

### Audio session

- ``AudioSession``
- ``AudioSessionPolicy``

### Recording

- ``VoiceoverRecorder``
- ``Voiceover``
- ``RecordingLatency``
- ``VoiceoverError``

### Loudness

- ``Loudness``
- ``LoudnessMeasurement``

### Files

- ``AudioFile``
- ``AudioFileInfo``
- ``AudioFileError``
