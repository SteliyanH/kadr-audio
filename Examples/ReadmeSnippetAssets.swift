import AVFoundation
import Foundation
import Kadr

// The names the README snippets use, so that they compile. Nothing here runs:
// the Examples target is built, never executed, so no placeholder reaches the
// music library or the microphone and no permission prompt can appear.
//
// Guarded like the snippets themselves (see Tools/readme-snippets.sh): the
// surface they exercise does not exist on macOS.

#if os(iOS) || os(visionOS)
import MediaPlayer

// The host app's state. Main-actor isolated, as it would be in a real app,
// because the snippets assign to it.
@MainActor var video = Video {}
@MainActor let player = AVPlayer()

/// What the user tapped in a music picker.
@MainActor let picked = MPMediaItem()

/// What a document picker returned.
let pickedURL = URL(fileURLWithPath: "/tmp/holiday.mov")
let musicURL = URL(fileURLWithPath: "/tmp/music.m4a")

/// The composition time the preview was showing when recording started.
let previewTime = CMTime(seconds: 4, preferredTimescale: 600)

/// The host's error presentation.
func show(_ message: String, _ suggestion: String?) {}
#endif
