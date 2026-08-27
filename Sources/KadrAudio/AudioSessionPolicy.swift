import Foundation

/// What the app is doing with audio, expressed as a value rather than as a pile of
/// `AVAudioSession` arguments.
///
/// Separating the *policy* from applying it is deliberate: the decision of which
/// category and options suit a use case is the part worth testing and the part worth
/// arguing about, and `AVAudioSession` cannot be exercised on a Mac. This type is
/// pure and available everywhere; ``AudioSession`` applies it and exists only on
/// platforms that have the framework.
public struct AudioSessionPolicy: Sendable, Equatable {

    /// How the session should behave alongside audio from other apps.
    public enum Sharing: Sendable, Equatable {
        /// Take over. Other apps' audio stops.
        ///
        /// The right default for an editor: the point of a preview is to hear
        /// exactly what was edited, and a podcast playing underneath makes that
        /// impossible to judge.
        case exclusive
        /// Play alongside whatever else is running.
        case mixWithOthers
        /// Play alongside, but quiet the other app while this one plays.
        case duckOthers
    }

    /// Whether the session records as well as plays.
    public let recordsInput: Bool

    /// How to coexist with other apps.
    public let sharing: Sharing

    /// Whether audio should be heard when the ring/silent switch is set to silent.
    ///
    /// **This is the setting that matters most, and the default that catches people.**
    /// A fresh app gets `.soloAmbient`, which obeys the switch — so a user with a
    /// muted phone opens a video editor and the preview is silent, with nothing on
    /// screen explaining why. Video playback is expected to ignore the switch;
    /// that is why every video app you have used does.
    public let playsThroughSilentSwitch: Bool

    public init(recordsInput: Bool, sharing: Sharing, playsThroughSilentSwitch: Bool) {
        self.recordsInput = recordsInput
        self.sharing = sharing
        self.playsThroughSilentSwitch = playsThroughSilentSwitch
    }

    /// Previewing a composition. Audible with the phone muted, and takes over from
    /// other audio.
    public static let preview = AudioSessionPolicy(
        recordsInput: false,
        sharing: .exclusive,
        playsThroughSilentSwitch: true
    )

    /// Recording a voiceover while the preview plays.
    ///
    /// Still plays through the silent switch — a voiceover is recorded *against*
    /// playback, so silencing the playback would defeat it.
    public static let voiceover = AudioSessionPolicy(
        recordsInput: true,
        sharing: .exclusive,
        playsThroughSilentSwitch: true
    )

    /// Background or incidental playback that should not interrupt the user.
    ///
    /// Obeys the silent switch, because audio the user did not ask for should be
    /// silenceable — the opposite of the preview case.
    public static let ambient = AudioSessionPolicy(
        recordsInput: false,
        sharing: .mixWithOthers,
        playsThroughSilentSwitch: false
    )
}
