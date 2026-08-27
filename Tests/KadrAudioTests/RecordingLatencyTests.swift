import Testing
import Foundation
@testable import KadrAudio
import CoreMedia
import Kadr

/// The latency arithmetic and the placement it drives. Both are pure, so both run
/// on the macOS host CI uses — `AVAudioRecorder` and `AVAudioSession` do not exist
/// there, and the recorder itself is a thin wrapper around them by design.
struct RecordingLatencyTests {

    // MARK: - The sum

    @Test func compensationIsTheSumOfBothDirectionsPlusTheBuffer() {
        let c = RecordingLatency.compensation(
            outputLatency: 0.080, inputLatency: 0.090, ioBufferDuration: 0.005
        )
        #expect(abs(c.seconds - 0.175) < 0.0001)
    }

    /// Wired headphones: a couple of milliseconds, and nobody notices.
    @Test func wiredLatencyIsImperceptible() {
        let c = RecordingLatency.compensation(
            outputLatency: 0.002, inputLatency: 0.002, ioBufferDuration: 0.005
        )
        #expect(RecordingLatency.isPerceptible(c) == false)
    }

    /// Bluetooth: several frames at 30 fps, and unmistakable on a lip-sync. This is
    /// the case the whole feature exists for.
    @Test func bluetoothLatencyIsPerceptible() {
        let c = RecordingLatency.compensation(
            outputLatency: 0.090, inputLatency: 0.090, ioBufferDuration: 0.010
        )
        #expect(RecordingLatency.isPerceptible(c))
        #expect(c.seconds > 0.15)
    }

    /// One frame at 30 fps is the threshold, so it must be on the perceptible side
    /// of it rather than ambiguous.
    @Test func oneFrameAtThirtyIsTheBoundary() {
        let oneFrame = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 48_000)
        #expect(RecordingLatency.isPerceptible(oneFrame))
        #expect(RecordingLatency.isPerceptible(CMTime(seconds: 0.030, preferredTimescale: 48_000)) == false)
    }

    /// An unknown latency is better treated as none than as a guess that shifts the
    /// take the wrong way.
    @Test func nonsenseInputsCompensateByNothing() {
        #expect(RecordingLatency.compensation(outputLatency: 0, inputLatency: 0, ioBufferDuration: 0) == .zero)
        #expect(RecordingLatency.compensation(outputLatency: -1, inputLatency: 0, ioBufferDuration: 0) == .zero)
        #expect(RecordingLatency.compensation(outputLatency: .nan, inputLatency: 0, ioBufferDuration: 0) == .zero)
        #expect(RecordingLatency.compensation(outputLatency: .infinity, inputLatency: 0, ioBufferDuration: 0) == .zero)
    }

    // MARK: - Placement

    @Test func takeIsPlacedEarlierByTheMeasuredLatency() {
        let take = Voiceover(
            url: URL(fileURLWithPath: "/tmp/v.m4a"),
            duration: CMTime(seconds: 4, preferredTimescale: 48_000),
            latencyCompensation: CMTime(seconds: 0.18, preferredTimescale: 48_000)
        )
        let track = take.audioTrack(startingAt: CMTime(seconds: 10, preferredTimescale: 48_000))
        let start = try! #require(track.startTime)
        #expect(abs(start.seconds - 9.82) < 0.001)
    }

    /// A take started in the first few frames would otherwise be placed at a
    /// negative time, which no composition can express.
    @Test func placementClampsAtZero() {
        let take = Voiceover(
            url: URL(fileURLWithPath: "/tmp/v.m4a"),
            duration: CMTime(seconds: 1, preferredTimescale: 48_000),
            latencyCompensation: CMTime(seconds: 0.2, preferredTimescale: 48_000)
        )
        let start = try! #require(take.audioTrack(startingAt: CMTime(seconds: 0.05, preferredTimescale: 48_000)).startTime)
        #expect(start == .zero)
    }

    @Test func zeroLatencyPlacesTheTakeWhereItStarted() {
        let take = Voiceover(
            url: URL(fileURLWithPath: "/tmp/v.m4a"),
            duration: CMTime(seconds: 2, preferredTimescale: 48_000),
            latencyCompensation: .zero
        )
        let start = try! #require(take.audioTrack(startingAt: CMTime(seconds: 5, preferredTimescale: 48_000)).startTime)
        #expect(start.seconds == 5)
    }

    // MARK: - Errors

    @Test func everyErrorHasASentence() {
        for error in [VoiceoverError.microphoneDenied, .couldNotStart, .notRecording] {
            #expect(error.errorDescription?.isEmpty == false, "\(error) has no description")
        }
    }

    /// Nothing useful can be done about calling stop twice, so no filler suggestion.
    @Test func notRecordingOffersNoHollowSuggestion() {
        #expect(VoiceoverError.notRecording.recoverySuggestion == nil)
        #expect(VoiceoverError.microphoneDenied.recoverySuggestion?.contains("Settings") == true)
    }
}
