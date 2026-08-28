import Foundation
import Kadr

extension AudioTrack {

    /// This track at the volume that lands `measurement` on `target`.
    ///
    /// ```swift
    /// let measured = try await Loudness.measure(url: musicURL)
    /// let track = AudioTrack(url: musicURL).normalized(from: measured, to: .social)
    /// ```
    ///
    /// Takes a measurement rather than making one, so the expensive part happens
    /// once and where the caller chooses — measuring a five-minute track reads
    /// every sample, and doing that inside a composition modifier would hide it.
    ///
    /// > **A gain above 1.0 raises peaks as well as loudness**, and nothing here
    /// > limits them, so a quiet source pushed to −14 LUFS may clip. Platforms
    /// > normalise downward far more often than upward, so the common direction is
    /// > the safe one — but it is worth checking rather than assuming.
    public func normalized(from measurement: LoudnessMeasurement, to target: Loudness.Target) -> AudioTrack {
        volume(Loudness.gain(from: measurement, to: target))
    }
}
