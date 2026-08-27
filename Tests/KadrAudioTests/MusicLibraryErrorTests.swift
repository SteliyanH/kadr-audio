import Testing
import Foundation
@testable import KadrAudio

/// The error surface is the part of this package that runs on every platform, and
/// the part a user actually reads. `MPMediaItem` cannot be constructed in a test —
/// it comes from the system library — so the resolution paths are exercised on
/// device, and what is testable here is the wording and the shape.
struct MusicLibraryErrorTests {

    @Test func protectedItemNamesTheTrack() {
        let error = MusicLibraryError.protectedItem(title: "Blue Monday")
        #expect(error.errorDescription == "“Blue Monday” can't be added to a video.")
    }

    /// A missing title must not produce “” with nothing in it.
    @Test func protectedItemWithoutATitleStillReads() throws {
        let text = try #require(MusicLibraryError.protectedItem(title: nil).errorDescription)
        #expect(text == "That track can't be added to a video.")
        #expect(!text.contains("“”"))
    }

    /// The recovery text is the whole value of this error. Without the reason, the
    /// obvious next move is to try another Apple Music track and fail identically.
    @Test func protectedItemExplainsWhyRatherThanSuggestingRetry() throws {
        let suggestion = try #require(MusicLibraryError.protectedItem(title: "x").recoverySuggestion)
        #expect(suggestion.contains("Apple Music"))
        #expect(!suggestion.lowercased().contains("try again"))
    }

    @Test func unauthorizedPointsAtSettings() throws {
        #expect(MusicLibraryError.unauthorized.errorDescription?.isEmpty == false)
        let suggestion = try #require(MusicLibraryError.unauthorized.recoverySuggestion)
        #expect(suggestion.contains("Settings"))
    }

    /// No useful action exists, so there is no suggestion. Filler in an error
    /// message costs trust.
    @Test func noAudioTrackOffersNoHollowSuggestion() {
        #expect(MusicLibraryError.noAudioTrack(title: "x").recoverySuggestion == nil)
    }

    @Test func noAudioTrackNamesTheItem() {
        #expect(MusicLibraryError.noAudioTrack(title: "Voice Memo").errorDescription?.contains("Voice Memo") == true)
    }

    @Test func errorsAreEquatable() {
        #expect(MusicLibraryError.protectedItem(title: "a") == .protectedItem(title: "a"))
        #expect(MusicLibraryError.protectedItem(title: "a") != .protectedItem(title: "b"))
        #expect(MusicLibraryError.unauthorized != .noAudioTrack(title: nil))
    }

    /// Every case must produce a sentence. A `LocalizedError` that returns nil for
    /// a case falls back to "The operation couldn't be completed", which is the
    /// exact failure this conformance exists to prevent.
    @Test func everyCaseHasADescription() {
        let all: [MusicLibraryError] = [
            .unauthorized,
            .protectedItem(title: "t"), .protectedItem(title: nil),
            .noAudioTrack(title: "t"), .noAudioTrack(title: nil),
        ]
        for error in all {
            #expect(error.errorDescription?.isEmpty == false, "\(error) has no description")
        }
    }
}
