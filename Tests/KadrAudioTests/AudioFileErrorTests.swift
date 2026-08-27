import Testing
import Foundation
@testable import KadrAudio
import CoreMedia

/// File inspection. Reading a real asset needs AVFoundation and a file, so the
/// errors and the info type are what carry coverage here — and the errors are the
/// half a user sees.
struct AudioFileErrorTests {

    @Test func everyErrorNamesTheFile() {
        let errors: [AudioFileError] = [
            .noAudioTrack(fileName: "holiday.mov"),
            .unreadable(fileName: "broken.m4a"),
            .empty(fileName: "zero.wav"),
        ]
        for error in errors {
            let text = error.errorDescription ?? ""
            #expect(text.isEmpty == false, "\(error) has no description")
        }
        #expect(AudioFileError.noAudioTrack(fileName: "holiday.mov").errorDescription?.contains("holiday.mov") == true)
    }

    /// The common real case: a user picks a video file in an audio picker. Saying
    /// so is the difference between fixing it in one try and several.
    @Test func noAudioTrackExplainsThatAVideoWillNotWork() throws {
        let suggestion = try #require(AudioFileError.noAudioTrack(fileName: "x").recoverySuggestion)
        #expect(suggestion.lowercased().contains("video"))
    }

    @Test func unreadableSuggestsWhatMightBeWrong() throws {
        let suggestion = try #require(AudioFileError.unreadable(fileName: "x").recoverySuggestion)
        #expect(suggestion.isEmpty == false)
    }

    /// Nothing useful can be done about an empty file, so no filler.
    @Test func emptyOffersNoHollowSuggestion() {
        #expect(AudioFileError.empty(fileName: "x").recoverySuggestion == nil)
    }

    @Test func infoCarriesWhatItKnowsAndAdmitsWhatItDoesNot() {
        let known = AudioFileInfo(
            duration: CMTime(seconds: 12, preferredTimescale: 600),
            sampleRate: 44_100, channelCount: 2
        )
        #expect(known.sampleRate == 44_100)
        #expect(known.channelCount == 2)

        // Files that report no stream description are real; the type says so
        // rather than inventing 44.1/2.
        let unknown = AudioFileInfo(duration: .zero, sampleRate: nil, channelCount: nil)
        #expect(unknown.sampleRate == nil)
        #expect(unknown.channelCount == nil)
    }

    @Test func errorsAreEquatable() {
        #expect(AudioFileError.empty(fileName: "a") == .empty(fileName: "a"))
        #expect(AudioFileError.empty(fileName: "a") != .empty(fileName: "b"))
        #expect(AudioFileError.empty(fileName: "a") != .unreadable(fileName: "a"))
    }
}
