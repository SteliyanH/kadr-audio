import Foundation
import CoreMedia

/// How far to shift a recording so it lines up with what the person heard.
///
/// **The problem.** A voiceover is performed against playback. The performer
/// reacts to audio that already left the device late, and their voice arrives at
/// the input late again. Both delays land in the recording, so the take is behind
/// the picture by the sum of them — and on AirPods that sum is large enough to
/// look like a sync bug rather than a timing subtlety.
///
/// Wired headphones add a couple of milliseconds. Bluetooth adds **150–200 ms**,
/// which is several frames at 30 fps and unmistakable on a lip-sync.
///
/// **Why this is a separate type.** The arithmetic is the part worth testing and
/// arguing about; reading the numbers out of `AVAudioSession` is a property access
/// that cannot run off-device. Keeping them apart is what gives this coverage —
/// the same split as ``AudioSessionPolicy`` and ``AudioSession``.
public enum RecordingLatency {

    /// The offset to subtract from a recording's start so it aligns with playback.
    ///
    /// - Parameters:
    ///   - outputLatency: seconds between the engine emitting audio and the person
    ///     hearing it.
    ///   - inputLatency: seconds between the person speaking and the sample being
    ///     captured.
    ///   - ioBufferDuration: the session's buffer period, which contributes once.
    ///
    /// Returns `.zero` for non-finite or negative inputs rather than a nonsense
    /// offset: an unknown latency is better treated as none than as a guess that
    /// shifts the take the wrong way.
    public static func compensation(
        outputLatency: TimeInterval,
        inputLatency: TimeInterval,
        ioBufferDuration: TimeInterval
    ) -> CMTime {
        let total = outputLatency + inputLatency + ioBufferDuration
        guard total.isFinite, total > 0 else { return .zero }
        return CMTime(seconds: total, preferredTimescale: 48_000)
    }

    /// Whether a measured latency is large enough to be worth telling the user
    /// about.
    ///
    /// One frame at 30 fps is 33 ms. Below that, compensation happens silently and
    /// nobody needs to know. Above it, a host may reasonably warn that a wired
    /// connection will give a better take — because compensation shifts a recording
    /// into alignment but cannot undo what the performer heard while performing.
    public static func isPerceptible(_ compensation: CMTime) -> Bool {
        compensation.seconds >= 1.0 / 30.0
    }
}
