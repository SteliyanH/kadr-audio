import Testing
import Foundation
@testable import KadrAudio

/// The policy is the part worth testing: choosing a category and options is where
/// the decisions live, and it is pure, so it runs on every platform including the
/// macOS host CI uses. Applying the policy is a thin call into `AVAudioSession`,
/// which cannot be exercised off-device at all.
///
/// Splitting them that way is the only reason any of this has coverage.
struct AudioSessionPolicyTests {

    // MARK: - The setting that caused the bug

    /// The whole reason v0.2 exists. A fresh app gets `.soloAmbient`, which obeys
    /// the ring/silent switch — so a muted phone means a silent editor with nothing
    /// explaining why. Preview must not inherit that.
    @Test func previewPlaysThroughTheSilentSwitch() {
        #expect(AudioSessionPolicy.preview.playsThroughSilentSwitch)
    }

    /// A voiceover is recorded *against* playback. Silencing the playback would
    /// defeat the recording, so this must not be "quieter" than preview.
    @Test func voiceoverAlsoPlaysThroughTheSilentSwitch() {
        #expect(AudioSessionPolicy.voiceover.playsThroughSilentSwitch)
    }

    /// The deliberate opposite: audio the user did not ask for should be
    /// silenceable.
    @Test func ambientObeysTheSilentSwitch() {
        #expect(AudioSessionPolicy.ambient.playsThroughSilentSwitch == false)
    }

    // MARK: - Sharing

    /// An editor preview takes over. The point of a preview is judging exactly what
    /// was edited, and a podcast underneath makes that impossible.
    @Test func previewIsExclusive() {
        #expect(AudioSessionPolicy.preview.sharing == .exclusive)
    }

    @Test func ambientMixes() {
        #expect(AudioSessionPolicy.ambient.sharing == .mixWithOthers)
    }

    // MARK: - Input

    @Test func onlyVoiceoverRecords() {
        #expect(AudioSessionPolicy.voiceover.recordsInput)
        #expect(AudioSessionPolicy.preview.recordsInput == false)
        #expect(AudioSessionPolicy.ambient.recordsInput == false)
    }

    // MARK: - Custom policies

    @Test func policiesAreEquatableAndConstructible() {
        let a = AudioSessionPolicy(recordsInput: false, sharing: .duckOthers, playsThroughSilentSwitch: true)
        let b = AudioSessionPolicy(recordsInput: false, sharing: .duckOthers, playsThroughSilentSwitch: true)
        #expect(a == b)
        #expect(a != .preview)
    }

    /// The presets are distinct. Two that compared equal would mean one of them is
    /// not carrying its own decision.
    @Test func theThreePresetsDiffer() {
        #expect(AudioSessionPolicy.preview != AudioSessionPolicy.voiceover)
        #expect(AudioSessionPolicy.preview != AudioSessionPolicy.ambient)
        #expect(AudioSessionPolicy.voiceover != AudioSessionPolicy.ambient)
    }
}
