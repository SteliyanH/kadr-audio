import Foundation
import Testing
@testable import KadrAudio

struct VersionTests {

    /// kadr-photos' `version` said "0.1.0-dev" through eleven releases because
    /// nothing tied it to anything. This one must match the newest released
    /// heading in CHANGELOG.md, which every release writes anyway.
    @Test func versionMatchesNewestChangelogRelease() throws {
        let changelog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // KadrAudioTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("CHANGELOG.md")
        let text = try String(contentsOf: changelog, encoding: .utf8)
        let newest = text.split(separator: "\n").lazy
            .filter { $0.hasPrefix("## [") && !$0.hasPrefix("## [Unreleased]") }
            .compactMap { $0.dropFirst(4).split(separator: "]").first.map(String.init) }
            .first
        #expect(newest == KadrAudio.version)
    }
}
