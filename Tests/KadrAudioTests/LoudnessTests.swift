import Testing
import Foundation
@testable import KadrAudio

/// Loudness measurement, per ITU-R BS.1770-4.
///
/// These test *properties* rather than absolute values against a reference
/// implementation. Asserting "a 1 kHz sine at −20 dBFS measures −21.3 LUFS" would
/// pin this to one particular filter implementation and break on any legitimate
/// refinement. Asserting "doubling the amplitude raises loudness by about 6 dB"
/// holds for any correct implementation and fails for most incorrect ones.
struct LoudnessTests {

    private let sampleRate = 48_000.0

    /// A sine at a given peak amplitude, `seconds` long, mono.
    private func sine(amplitude: Double, seconds: Double, frequency: Double = 1_000) -> [Float] {
        let count = Int(sampleRate * seconds)
        return (0..<count).map { i in
            Float(amplitude * sin(2 * .pi * frequency * Double(i) / sampleRate))
        }
    }

    // MARK: - Silence

    @Test func digitalSilenceIsSilent() {
        let m = Loudness.integrated(
            samples: [Float](repeating: 0, count: 48_000),
            sampleRate: sampleRate, channels: 1
        )
        #expect(m.isSilent)
    }

    @Test func emptyInputIsSilent() {
        #expect(Loudness.integrated(samples: [], sampleRate: sampleRate, channels: 1).isSilent)
    }

    /// Multiplying silence by anything is still silence, so a normalising gain here
    /// is meaningless. Returning 1.0 beats returning the enormous number the naive
    /// calculation produces.
    @Test func silenceAsksForNoGain() {
        let silent = LoudnessMeasurement(integratedLUFS: -.infinity, isSilent: true)
        #expect(Loudness.gain(from: silent, to: .social) == 1.0)
    }

    // MARK: - The properties that catch a wrong implementation

    /// Doubling amplitude is +6.02 dB. Any correct implementation reproduces this;
    /// a broken filter or a mean/sum confusion does not.
    @Test func doublingAmplitudeRaisesLoudnessBySixDecibels() {
        let quiet = Loudness.integrated(samples: sine(amplitude: 0.1, seconds: 3), sampleRate: sampleRate, channels: 1)
        let loud = Loudness.integrated(samples: sine(amplitude: 0.2, seconds: 3), sampleRate: sampleRate, channels: 1)
        let delta = loud.integratedLUFS - quiet.integratedLUFS
        #expect(abs(delta - 6.02) < 0.2, "expected ~6.02 dB, got \(delta)")
    }

    /// Ten times the amplitude is +20 dB.
    @Test func tenfoldAmplitudeRaisesLoudnessByTwentyDecibels() {
        let quiet = Loudness.integrated(samples: sine(amplitude: 0.05, seconds: 3), sampleRate: sampleRate, channels: 1)
        let loud = Loudness.integrated(samples: sine(amplitude: 0.5, seconds: 3), sampleRate: sampleRate, channels: 1)
        let delta = loud.integratedLUFS - quiet.integratedLUFS
        #expect(abs(delta - 20.0) < 0.3, "expected ~20 dB, got \(delta)")
    }

    /// Loudness is a rate, not a total: the same signal for longer is not louder.
    @Test func lengthDoesNotChangeLoudness() {
        let short = Loudness.integrated(samples: sine(amplitude: 0.3, seconds: 2), sampleRate: sampleRate, channels: 1)
        let long = Loudness.integrated(samples: sine(amplitude: 0.3, seconds: 6), sampleRate: sampleRate, channels: 1)
        #expect(abs(short.integratedLUFS - long.integratedLUFS) < 0.5)
    }

    @Test func loudnessIsNegativeBelowFullScale() {
        let m = Loudness.integrated(samples: sine(amplitude: 0.25, seconds: 3), sampleRate: sampleRate, channels: 1)
        #expect(m.integratedLUFS < 0)
        #expect(m.integratedLUFS > -70)
        #expect(m.isSilent == false)
    }

    // MARK: - Gating

    /// The relative gate is what stops a quiet passage dragging the measurement
    /// down. A signal that is loud for half its length and silent for the other
    /// half should measure close to the loud part alone — not 3 dB below it, which
    /// is what a straight average would give.
    @Test func silencePassagesAreGatedOut() {
        let loud = sine(amplitude: 0.3, seconds: 3)
        let padded = loud + [Float](repeating: 0, count: Int(sampleRate * 3))

        let loudOnly = Loudness.integrated(samples: loud, sampleRate: sampleRate, channels: 1)
        let withSilence = Loudness.integrated(samples: padded, sampleRate: sampleRate, channels: 1)

        #expect(abs(loudOnly.integratedLUFS - withSilence.integratedLUFS) < 1.0,
                "gating should discard the silent half, not average it in")
    }

    // MARK: - Short signals

    /// A 200 ms sound effect is shorter than the 400 ms gating block. It is not
    /// silent, and reporting it as such would be worse than measuring it ungated.
    @Test func signalsShorterThanOneBlockAreStillMeasured() {
        let m = Loudness.integrated(samples: sine(amplitude: 0.3, seconds: 0.2), sampleRate: sampleRate, channels: 1)
        #expect(m.isSilent == false)
        #expect(m.integratedLUFS.isFinite)
    }

    // MARK: - Channels

    @Test func stereoIsLouderThanMonoAtTheSameAmplitude() {
        let mono = sine(amplitude: 0.3, seconds: 3)
        var stereo: [Float] = []
        for sample in mono { stereo.append(sample); stereo.append(sample) }

        let m = Loudness.integrated(samples: mono, sampleRate: sampleRate, channels: 1)
        let s = Loudness.integrated(samples: stereo, sampleRate: sampleRate, channels: 2)
        #expect(s.integratedLUFS > m.integratedLUFS,
                "two channels carrying the same signal sum to more power than one")
    }

    // MARK: - Targets and gain

    @Test func platformTargets() {
        #expect(Loudness.Target.social.lufs == -14)
        #expect(Loudness.Target.podcast.lufs == -16)
        #expect(Loudness.Target.broadcast.lufs == -23)
        #expect(Loudness.Target.custom(-18).lufs == -18)
    }

    /// Too loud for the platform means turning down: a gain below 1.
    @Test func aLoudSourceIsTurnedDown() {
        let m = LoudnessMeasurement(integratedLUFS: -8, isSilent: false)
        let g = Loudness.gain(from: m, to: .social)
        #expect(g < 1.0)
        #expect(abs(g - pow(10.0, -6.0 / 20.0)) < 0.0001)
    }

    @Test func aQuietSourceIsTurnedUp() {
        let m = LoudnessMeasurement(integratedLUFS: -24, isSilent: false)
        #expect(Loudness.gain(from: m, to: .social) > 1.0)
    }

    @Test func alreadyOnTargetNeedsNoChange() {
        let m = LoudnessMeasurement(integratedLUFS: -14, isSilent: false)
        #expect(abs(Loudness.gain(from: m, to: .social) - 1.0) < 0.0001)
    }

    /// Applying the gain must actually land on the target — the round trip is what
    /// a caller depends on.
    @Test func measureThenGainThenMeasureLandsOnTarget() {
        let original = Loudness.integrated(samples: sine(amplitude: 0.2, seconds: 3), sampleRate: sampleRate, channels: 1)
        let g = Loudness.gain(from: original, to: .custom(-20))
        let adjusted = sine(amplitude: 0.2, seconds: 3).map { Float(Double($0) * g) }
        let after = Loudness.integrated(samples: adjusted, sampleRate: sampleRate, channels: 1)
        #expect(abs(after.integratedLUFS - (-20)) < 0.3, "landed at \(after.integratedLUFS)")
    }

    // MARK: - measure(url:)
    //
    // The file path was missing until now, which made the whole feature
    // unreachable: `integrated` takes samples, and nothing produced them. A doc
    // comment even referenced `Loudness.measure(url:)` as though it existed.

    @Test func measuringAFileWithNoAudioNamesTheFile() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("kadr-not-audio-\(UUID().uuidString).txt")
        try? "not audio".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await Loudness.measure(url: url)
            Issue.record("expected a failure for a text file")
        } catch let error as AudioFileError {
            // Either "no audio track" or "unreadable" is correct here; what matters
            // is that it is an AudioFileError naming the file, not an AVFoundation
            // code naming nothing.
            #expect(error.errorDescription?.contains(url.lastPathComponent) == true)
        } catch {
            Issue.record("expected AudioFileError, got \(error)")
        }
    }

    @Test func measuringAMissingFileFails() async {
        let url = URL(fileURLWithPath: "/tmp/kadr-does-not-exist-\(UUID().uuidString).m4a")
        do {
            _ = try await Loudness.measure(url: url)
            Issue.record("expected a failure for a missing file")
        } catch is AudioFileError {
            // Correct: the failure names the file.
        } catch {
            Issue.record("expected AudioFileError, got \(error)")
        }
    }
}
