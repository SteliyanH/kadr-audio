import Foundation
import AVFoundation
import CoreMedia
import Kadr

/// What is actually in an audio file, and whether kadr can use it.
public struct AudioFileInfo: Sendable, Equatable {

    /// How long the audio runs.
    public let duration: CMTime

    /// Sample rate in hertz, or `nil` when the file does not report one.
    public let sampleRate: Double?

    /// Channel count, or `nil` when unreported.
    public let channelCount: Int?

    public init(duration: CMTime, sampleRate: Double?, channelCount: Int?) {
        self.duration = duration
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

/// Why a file could not be used.
public enum AudioFileError: Error, Sendable, Equatable {
    /// Nothing in the file is an audio track — a renamed video, or a `.m4a` that
    /// turns out to be video-only.
    case noAudioTrack(fileName: String)
    /// The file exists but cannot be read as media at all.
    case unreadable(fileName: String)
    /// The audio has no duration to speak of.
    case empty(fileName: String)
}

extension AudioFileError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case let .noAudioTrack(name): return "“\(name)” doesn't contain any audio."
        case let .unreadable(name):   return "“\(name)” couldn't be opened."
        case let .empty(name):        return "“\(name)” is empty."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .noAudioTrack:
            return "Pick a music or voice file — a video file won't work here."
        case .unreadable:
            return "The file may be damaged, or in a format this device can't read."
        case .empty:
            return nil
        }
    }
}

/// Checking an audio file before it reaches a composition.
///
/// **Why this exists.** A file picker returns a URL, and a content-type filter is a
/// guess: `.audio` admits files with no decodable audio track, and a user can
/// rename anything. Handing such a URL to `AudioTrack` produces a composition that
/// builds and exports silently wrong, or fails deep inside AVFoundation with an
/// error naming neither the file nor the problem.
///
/// The reference app hand-rolls exactly this today — a `fileImporter` with a
/// guessed type list and no validation at all.
public enum AudioFile {

    /// Read what is in the file, or throw explaining why it cannot be used.
    ///
    /// ```swift
    /// let info = try await AudioFile.inspect(url)      // throws with a sentence
    /// video = video.audio { AudioTrack(url: url) }
    /// ```
    public static func inspect(_ url: URL) async throws -> AudioFileInfo {
        let name = url.lastPathComponent
        let asset = AVURLAsset(url: url)

        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw AudioFileError.unreadable(fileName: name)
        }
        guard let track = tracks.first else {
            throw AudioFileError.noAudioTrack(fileName: name)
        }

        let duration = (try? await asset.load(.duration)) ?? .zero
        guard duration.seconds.isFinite, duration.seconds > 0 else {
            throw AudioFileError.empty(fileName: name)
        }

        let descriptions = (try? await track.load(.formatDescriptions)) ?? []
        let basic = descriptions.first.flatMap {
            CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee
        }

        return AudioFileInfo(
            duration: duration,
            sampleRate: basic.map(\.mSampleRate),
            channelCount: basic.map { Int($0.mChannelsPerFrame) }
        )
    }

    /// An ``Kadr/AudioTrack`` for `url`, after checking it is usable.
    ///
    /// Prefer this over constructing `AudioTrack(url:)` from a picker result. The
    /// check costs one asset load and turns a silent failure at export into a
    /// sentence at import.
    public static func audioTrack(for url: URL) async throws -> AudioTrack {
        _ = try await inspect(url)
        return AudioTrack(url: url)
    }
}
