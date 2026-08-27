import Foundation
import Kadr
import CoreMedia
// `canImport(MediaPlayer)` is true on macOS — the framework exists there, but
// MPMediaLibrary, MPMediaQuery and MPMediaItem are all marked unavailable. The
// guard has to be about the platform, not the module.
#if os(iOS) || os(visionOS)
import MediaPlayer
#endif

/// Resolves music-library items into kadr audio.
///
/// **Why this is a separate package.** kadr core is AVFoundation-only by policy.
/// MediaPlayer is a different framework with its own privacy prompt
/// (`NSAppleMusicUsageDescription`) and its own platform limits, so it lives here
/// for the same reason `Photos` lives in kadr-photos — the dependency, not the
/// topic.
///
/// **What it absorbs.** The library's shape is not obvious from its types: most
/// items a user can pick cannot actually be used. Apple Music tracks are
/// DRM-protected and expose no asset URL, and there is no API that produces one.
/// A consumer that does not know this ships a picker where roughly everything the
/// user taps fails with nothing useful said.
public enum MusicLibrary {

    #if os(iOS) || os(visionOS)

    /// Whether the user has granted music-library access.
    public static var isAuthorized: Bool {
        MPMediaLibrary.authorizationStatus() == .authorized
    }

    /// Ask for music-library access.
    ///
    /// Returns the resulting status rather than a `Bool`, because `.denied` and
    /// `.restricted` need different interfaces: one can be fixed in Settings, the
    /// other cannot be fixed by the user at all.
    @discardableResult
    public static func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus {
        await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) }
        }
    }

    /// An ``Kadr/AudioTrack`` for `item`, ready to drop into a composition.
    ///
    /// ```swift
    /// let track = try MusicLibrary.audioTrack(for: picked)
    /// let video = Video { clips }.music(track.volume(0.4).ducking(0.2))
    /// ```
    ///
    /// - Throws: ``MusicLibraryError/protectedItem(title:)`` for anything from
    ///   Apple Music, which is most of a typical library. Surface that message —
    ///   it is the difference between a user understanding the limit and trying
    ///   another six songs.
    public static func audioTrack(for item: MPMediaItem) throws -> AudioTrack {
        guard isAuthorized else { throw MusicLibraryError.unauthorized }
        guard let url = item.assetURL else {
            throw MusicLibraryError.protectedItem(title: item.title)
        }
        return AudioTrack(url: url)
    }

    /// Every item in the user's library that kadr can actually use.
    ///
    /// Filtered by `assetURL`, so the result is what a picker should offer rather
    /// than what the library contains. Presenting the unfiltered set is the
    /// mistake this exists to prevent.
    public static func usableSongs() throws -> [MPMediaItem] {
        guard isAuthorized else { throw MusicLibraryError.unauthorized }
        let query = MPMediaQuery.songs()
        return (query.items ?? []).filter { $0.assetURL != nil }
    }

    #endif
}
