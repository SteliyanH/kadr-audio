import Foundation
import Kadr
#if os(iOS) || os(visionOS)
import MediaPlayer
#endif

/// A credit line for music used in a video.
///
/// Platforms expect attribution when a video uses someone else's music, and the
/// information is already attached to the item the user picked — so the tedious
/// part is not finding it, it is formatting it consistently and handling the
/// fields that are missing more often than anyone expects.
public struct MusicAttribution: Sendable, Equatable {

    /// Track title, if the item has one.
    public let title: String?

    /// Performing artist, if the item has one.
    public let artist: String?

    public init(title: String?, artist: String?) {
        self.title = title
        self.artist = artist
    }

    /// The credit as a single line, or `nil` when there is nothing to credit.
    ///
    /// `"Title — Artist"` when both are present, and just the one that exists when
    /// only one does. **Returns `nil` rather than an empty or dangling string when
    /// neither is**: a credit line reading `" — "` is worse than no credit line,
    /// and library items missing both fields are common enough that this is not a
    /// theoretical case.
    public var creditLine: String? {
        switch (title?.nonEmpty, artist?.nonEmpty) {
        case let (title?, artist?): return "\(title) — \(artist)"
        case let (title?, nil):     return title
        case let (nil, artist?):    return artist
        case (nil, nil):            return nil
        }
    }

    /// The credit as a ``Kadr/TextOverlay``, or `nil` when there is nothing to
    /// credit.
    ///
    /// Positioned at ``Kadr/Position/bottom`` by default, which is where platforms
    /// and viewers both expect a credit.
    public func overlay(style: TextStyle = .default) -> TextOverlay? {
        guard let line = creditLine else { return nil }
        return TextOverlay(line, style: style)
            .position(.bottom)
            .anchor(.bottom)
    }

    #if os(iOS) || os(visionOS)
    /// Attribution for a library item.
    public init(item: MPMediaItem) {
        self.title = item.title
        self.artist = item.artist
    }
    #endif
}

private extension String {
    /// `nil` for a string that is empty or only whitespace. Library metadata
    /// contains both, and treating `"  "` as a title produces a credit line made
    /// of spaces.
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
