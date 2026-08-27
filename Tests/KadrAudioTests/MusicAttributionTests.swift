import Testing
import Foundation
@testable import KadrAudio
import Kadr

/// Attribution formatting. `MPMediaItem` cannot be constructed in a test — it comes
/// from the system library — so what is testable is the part that actually goes
/// wrong: which fields are missing, and what happens when they are.
struct MusicAttributionTests {

    @Test func bothFieldsJoin() {
        let credit = MusicAttribution(title: "Blue Monday", artist: "New Order")
        #expect(credit.creditLine == "Blue Monday — New Order")
    }

    @Test func aMissingArtistLeavesJustTheTitle() {
        #expect(MusicAttribution(title: "Untitled", artist: nil).creditLine == "Untitled")
    }

    @Test func aMissingTitleLeavesJustTheArtist() {
        #expect(MusicAttribution(title: nil, artist: "Aphex Twin").creditLine == "Aphex Twin")
    }

    /// A credit line reading `" — "` is worse than no credit line, and library
    /// items missing both fields are common enough that this is not theoretical.
    @Test func neitherFieldProducesNoCreditRatherThanADanglingDash() {
        #expect(MusicAttribution(title: nil, artist: nil).creditLine == nil)
    }

    /// Library metadata contains empty and whitespace-only strings. Treating `"  "`
    /// as a title produces a credit made of spaces.
    @Test func whitespaceOnlyFieldsCountAsMissing() {
        #expect(MusicAttribution(title: "   ", artist: "  \n ").creditLine == nil)
        #expect(MusicAttribution(title: "  ", artist: "Real Artist").creditLine == "Real Artist")
    }

    @Test func fieldsAreTrimmed() {
        #expect(MusicAttribution(title: "  Song  ", artist: " Band ").creditLine == "Song — Band")
    }

    // MARK: - The overlay

    @Test func overlayIsNilWhenThereIsNothingToCredit() {
        #expect(MusicAttribution(title: nil, artist: nil).overlay() == nil)
    }

    @Test func overlayCarriesTheCreditLine() throws {
        let overlay = try #require(MusicAttribution(title: "Song", artist: "Band").overlay())
        #expect(overlay.text == "Song — Band")
    }

    @Test func attributionIsEquatable() {
        #expect(MusicAttribution(title: "a", artist: "b") == MusicAttribution(title: "a", artist: "b"))
        #expect(MusicAttribution(title: "a", artist: "b") != MusicAttribution(title: "a", artist: "c"))
    }
}
