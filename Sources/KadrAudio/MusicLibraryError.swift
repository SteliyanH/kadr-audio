import Foundation

/// Failures resolving a music-library item into something kadr can use.
public enum MusicLibraryError: Error, Sendable, Equatable {

    /// The user has not granted access to the music library.
    case unauthorized

    /// The item has no local asset URL.
    ///
    /// **This is the common case, not an edge case.** Apple Music tracks are
    /// DRM-protected: `MPMediaItem.assetURL` is `nil` for anything streamed or
    /// downloaded from a subscription, and there is no API that turns one into a
    /// file. Only items the user owns — purchased or synced from their own
    /// library — expose a URL.
    case protectedItem(title: String?)

    /// The item exists but carries no playable audio.
    case noAudioTrack(title: String?)
}
