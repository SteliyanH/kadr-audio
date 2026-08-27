import Foundation

/// The result of measuring a signal's loudness.
public struct LoudnessMeasurement: Sendable, Equatable {

    /// Integrated loudness in LUFS, per ITU-R BS.1770-4.
    ///
    /// Negative for anything short of digital full scale. Typical speech sits
    /// around −20, a mastered music track around −9 to −14.
    public let integratedLUFS: Double

    /// `true` when nothing survived the absolute gate at −70 LUFS.
    ///
    /// Distinguished from "very quiet" because a normalising gain is meaningless
    /// here: multiplying silence by anything is still silence, and a naive
    /// calculation would ask for an enormous boost.
    public let isSilent: Bool

    public init(integratedLUFS: Double, isSilent: Bool) {
        self.integratedLUFS = integratedLUFS
        self.isSilent = isSilent
    }
}

/// Loudness measurement and normalisation, per ITU-R BS.1770-4.
///
/// **Why this matters more than it sounds.** Every social platform normalises on
/// upload — Instagram, TikTok and YouTube all target roughly −14 LUFS. A
/// composition mixed by ear is therefore re-levelled *after* publishing, usually
/// downward, and unevenly across clips that were mixed at different times.
/// Measuring and normalising before export is the only way to control what the
/// platform does rather than discover it.
///
/// **This is pure arithmetic**, deliberately: it takes samples, not URLs, so it can
/// be tested anywhere. Reading samples out of an asset is a separate, thin step.
public enum Loudness {

    /// A platform's normalisation target.
    public enum Target: Sendable, Equatable {
        /// −14 LUFS. Instagram, TikTok and YouTube all sit at or near this.
        case social
        /// −16 LUFS, the common target for spoken-word podcasts.
        case podcast
        /// −23 LUFS, the EBU R128 broadcast standard.
        case broadcast
        /// Any other target, in LUFS.
        case custom(Double)

        public var lufs: Double {
            switch self {
            case .social: return -14
            case .podcast: return -16
            case .broadcast: return -23
            case .custom(let value): return value
            }
        }
    }

    /// Integrated loudness of interleaved samples.
    ///
    /// - Parameters:
    ///   - samples: interleaved, normalised to `-1.0...1.0`.
    ///   - sampleRate: in hertz.
    ///   - channels: 1 or 2. More are treated as stereo pairs.
    ///
    /// > The K-weighting coefficients in BS.1770 are specified at 48 kHz and are
    /// > applied directly here. That is exact for 48 kHz material and an
    /// > approximation elsewhere — the error is small for the 44.1 kHz that most
    /// > consumer audio arrives at, and this is what most implementations do, but
    /// > it is an approximation and saying so costs nothing.
    public static func integrated(samples: [Float], sampleRate: Double, channels: Int) -> LoudnessMeasurement {
        guard !samples.isEmpty, sampleRate > 0, channels > 0 else {
            return LoudnessMeasurement(integratedLUFS: -.infinity, isSilent: true)
        }

        // De-interleave, then K-weight each channel independently.
        let frameCount = samples.count / channels
        guard frameCount > 0 else {
            return LoudnessMeasurement(integratedLUFS: -.infinity, isSilent: true)
        }

        var weighted: [[Double]] = []
        for channel in 0..<channels {
            var signal = [Double](repeating: 0, count: frameCount)
            for frame in 0..<frameCount {
                signal[frame] = Double(samples[frame * channels + channel])
            }
            weighted.append(kWeighted(signal))
        }

        // 400 ms blocks, 75% overlap — the standard's gating window.
        let blockSize = Int(0.400 * sampleRate)
        let hop = max(1, blockSize / 4)
        guard blockSize > 0, frameCount >= blockSize else {
            // Too short to gate. Measure the whole thing as one block rather than
            // reporting silence: a 200 ms sound effect is not silent.
            let power = meanSquarePower(weighted, from: 0, count: frameCount)
            let lufs = loudness(ofPower: power)
            return LoudnessMeasurement(integratedLUFS: lufs, isSilent: !lufs.isFinite)
        }

        var blockPowers: [Double] = []
        var start = 0
        while start + blockSize <= frameCount {
            blockPowers.append(meanSquarePower(weighted, from: start, count: blockSize))
            start += hop
        }

        // Absolute gate: blocks quieter than −70 LUFS never count.
        let absolute = blockPowers.filter { loudness(ofPower: $0) > -70 }
        guard !absolute.isEmpty else {
            return LoudnessMeasurement(integratedLUFS: -.infinity, isSilent: true)
        }

        // Relative gate: −10 LU below the loudness of what survived the first gate.
        let ungated = loudness(ofPower: absolute.reduce(0, +) / Double(absolute.count))
        let threshold = ungated - 10
        let gated = absolute.filter { loudness(ofPower: $0) > threshold }
        let surviving = gated.isEmpty ? absolute : gated

        let mean = surviving.reduce(0, +) / Double(surviving.count)
        return LoudnessMeasurement(integratedLUFS: loudness(ofPower: mean), isSilent: false)
    }

    /// The linear gain that moves `measurement` to `target`.
    ///
    /// Returns `1.0` — no change — for silence, because multiplying silence by
    /// anything is still silence and the naive calculation asks for an enormous
    /// boost.
    ///
    /// > **Boosting can clip.** A gain above 1.0 raises peaks as well as loudness,
    /// > and nothing here limits them. Platforms normalise *downward* far more
    /// > often than upward, so the useful direction is usually the safe one — but a
    /// > quiet source pushed to −14 LUFS may distort, and this returns the number
    /// > rather than deciding for you.
    public static func gain(from measurement: LoudnessMeasurement, to target: Target) -> Double {
        guard !measurement.isSilent, measurement.integratedLUFS.isFinite else { return 1.0 }
        let deltaDB = target.lufs - measurement.integratedLUFS
        return pow(10.0, deltaDB / 20.0)
    }

    // MARK: - The filters

    /// BS.1770 K-weighting: a high-shelf approximating the head, then a high-pass.
    private static func kWeighted(_ signal: [Double]) -> [Double] {
        let shelved = biquad(
            signal,
            b0: 1.53512485958697, b1: -2.69169618940638, b2: 1.19839281085285,
            a1: -1.69065929318241, a2: 0.73248077421585
        )
        return biquad(
            shelved,
            b0: 1.0, b1: -2.0, b2: 1.0,
            a1: -1.99004745483398, a2: 0.99007225036621
        )
    }

    private static func biquad(
        _ x: [Double],
        b0: Double, b1: Double, b2: Double, a1: Double, a2: Double
    ) -> [Double] {
        var y = [Double](repeating: 0, count: x.count)
        var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
        for i in 0..<x.count {
            let out = b0 * x[i] + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            y[i] = out
            x2 = x1; x1 = x[i]
            y2 = y1; y1 = out
        }
        return y
    }

    /// Channel-weighted mean square across a window. L and R weigh 1.0; the
    /// standard's higher weights apply to surround channels this does not model.
    private static func meanSquarePower(_ channels: [[Double]], from start: Int, count: Int) -> Double {
        var total = 0.0
        for channel in channels {
            var sum = 0.0
            for i in start..<(start + count) where i < channel.count {
                sum += channel[i] * channel[i]
            }
            total += sum / Double(count)
        }
        return total
    }

    /// BS.1770's loudness from mean-square power.
    private static func loudness(ofPower power: Double) -> Double {
        guard power > 0 else { return -.infinity }
        return -0.691 + 10 * log10(power)
    }
}
