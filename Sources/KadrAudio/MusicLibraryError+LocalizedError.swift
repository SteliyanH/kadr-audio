import Foundation

/// Human-readable text for every ``MusicLibraryError``.
///
/// The wording matters more here than in most adapters, because the failure a
/// user hits most often is not their fault and is not fixable by retrying: an
/// Apple Music track simply cannot be exported. Saying so plainly, once, beats a
/// vague failure that invites them to try again with a different song and hit the
/// same wall.
extension MusicLibraryError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Reels needs permission to use your music."
        case let .protectedItem(title):
            if let title {
                return "“\(title)” can't be added to a video."
            }
            return "That track can't be added to a video."
        case let .noAudioTrack(title):
            if let title {
                return "“\(title)” doesn't contain any audio."
            }
            return "That item doesn't contain any audio."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unauthorized:
            return "Allow access in Settings, then try again."
        case .protectedItem:
            // Naming the reason is the whole value: without it, the natural next
            // move is to try another Apple Music track and fail identically.
            return "Songs from Apple Music are protected and can't be exported. Music you own or imported yourself will work."
        case .noAudioTrack:
            return nil
        }
    }
}
