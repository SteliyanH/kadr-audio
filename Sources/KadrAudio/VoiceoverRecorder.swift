import Foundation
import CoreMedia
import Kadr
#if os(iOS) || os(visionOS)
import AVFAudio
#endif

/// A finished take.
public struct Voiceover: Sendable, Equatable {

    /// Where the audio was written. The caller owns the file.
    public let url: URL

    /// How long the take runs.
    public let duration: CMTime

    /// How far the take was behind what the performer heard, measured at the moment
    /// recording began. See ``RecordingLatency``.
    public let latencyCompensation: CMTime

    public init(url: URL, duration: CMTime, latencyCompensation: CMTime) {
        self.url = url
        self.duration = duration
        self.latencyCompensation = latencyCompensation
    }

    /// An ``Kadr/AudioTrack`` placed so the take lines up with the picture.
    ///
    /// `start` is where the performer began — the composition time the preview was
    /// showing when recording started. The latency measured at that moment is
    /// subtracted, because the take is behind by exactly that much.
    ///
    /// Clamped at zero: a take started in the first few frames would otherwise be
    /// placed at a negative time, which no composition can express.
    public func audioTrack(startingAt start: CMTime) -> AudioTrack {
        let corrected = CMTimeSubtract(start, latencyCompensation)
        let placed = corrected.seconds < 0 ? .zero : corrected
        return AudioTrack(url: url).at(time: placed)
    }
}

/// Records a voiceover against a playing preview.
///
/// The capability is free from Apple — `AVAudioRecorder` is a handful of lines.
/// What this absorbs is the part that is tedious and easy to get subtly wrong:
/// permission, session configuration, and the latency correction that decides
/// whether the take lands on the picture or a fifth of a second behind it.
@MainActor
public final class VoiceoverRecorder {

    #if os(iOS) || os(visionOS)

    private var recorder: AVAudioRecorder?
    private var compensationAtStart: CMTime = .zero
    private let outputURL: URL

    /// - Parameter url: where to write. Defaults to a uniquely-named file in the
    ///   temporary directory, which the caller owns.
    public init(writingTo url: URL? = nil) {
        self.outputURL = url ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("kadr-voiceover-\(UUID().uuidString)")
            .appendingPathExtension("m4a")
    }

    /// Whether the user has granted microphone access.
    public static var isAuthorized: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    /// Ask for microphone access.
    @discardableResult
    public static func requestAuthorization() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Begin recording.
    ///
    /// Configures the session for ``AudioSessionPolicy/voiceover`` and measures the
    /// round-trip latency *now* rather than at construction, because plugging in
    /// AirPods between the two changes the answer by two orders of magnitude.
    public func start() throws {
        guard Self.isAuthorized else { throw VoiceoverError.microphoneDenied }

        try AudioSession.configure(.voiceover)
        try AudioSession.activate()

        let session = AVAudioSession.sharedInstance()
        compensationAtStart = RecordingLatency.compensation(
            outputLatency: session.outputLatency,
            inputLatency: session.inputLatency,
            ioBufferDuration: session.ioBufferDuration
        )

        let recorder = try AVAudioRecorder(url: outputURL, settings: [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,          // a voice is not stereo
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ])
        guard recorder.record() else { throw VoiceoverError.couldNotStart }
        self.recorder = recorder
    }

    /// Stop, and return the take.
    public func stop() throws -> Voiceover {
        guard let recorder else { throw VoiceoverError.notRecording }
        let duration = CMTime(seconds: recorder.currentTime, preferredTimescale: 48_000)
        recorder.stop()
        self.recorder = nil
        try? AudioSession.deactivate()

        return Voiceover(
            url: outputURL,
            duration: duration,
            latencyCompensation: compensationAtStart
        )
    }

    /// Abandon the take and delete the file.
    public func cancel() {
        recorder?.stop()
        recorder = nil
        try? FileManager.default.removeItem(at: outputURL)
        try? AudioSession.deactivate()
    }

    #endif
}

/// Failures while recording a voiceover.
public enum VoiceoverError: Error, Sendable, Equatable {
    /// Microphone access has not been granted.
    case microphoneDenied
    /// The recorder refused to start.
    case couldNotStart
    /// `stop()` was called with nothing in progress.
    case notRecording
}

extension VoiceoverError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .microphoneDenied: return "Reels needs permission to use your microphone."
        case .couldNotStart:    return "Recording couldn't start."
        case .notRecording:     return "There's no recording in progress."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .microphoneDenied: return "Allow access in Settings, then try again."
        case .couldNotStart:    return "Another app may be using the microphone."
        case .notRecording:     return nil
        }
    }
}
