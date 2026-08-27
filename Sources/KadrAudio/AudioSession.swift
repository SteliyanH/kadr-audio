import Foundation
// AVAudioSession lives in AVFAudio and does not exist on macOS. Same guard as
// `MusicLibrary`, for the same reason: this package declares macOS so it can
// resolve against kadr and be tested in CI, not because the surface works there.
#if os(iOS) || os(visionOS)
import AVFAudio
#endif

/// Configures the system audio session for previewing and recording.
///
/// **Why this exists.** Nothing in the kadr family touched `AVAudioSession` before
/// v0.2, so a host app got whatever session it happened to be in — `.soloAmbient`
/// for a fresh app. That has three visible consequences, and the first is the one
/// users report as a bug:
///
/// - Preview audio is **silenced by the ring/silent switch**. A muted phone means a
///   silent editor, with nothing on screen saying so.
/// - An interruption — a call, Siri — stops playback and nothing resumes it.
/// - Starting a preview stops the user's music, without anyone deciding it should.
///
/// None of that is kadr core's business: session management is not composition, and
/// core is AVFoundation-only by policy. It is this package's, for the same reason
/// the music library is.
public enum AudioSession {

    #if os(iOS) || os(visionOS)

    /// Apply `policy` to the shared session, without activating it.
    ///
    /// Configuration and activation are separate calls because activation takes
    /// audio focus from other apps. A host that configures at launch and activates
    /// only while a preview is on screen behaves well; one that activates at launch
    /// silences the user's music for as long as the app is open.
    public static func configure(_ policy: AudioSessionPolicy) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            policy.recordsInput ? .playAndRecord : .playback,
            mode: .default,
            options: options(for: policy)
        )
    }

    /// Take audio focus.
    public static func activate() throws {
        try AVAudioSession.sharedInstance().setActive(true)
    }

    /// Give audio focus back.
    ///
    /// `notifyOthers` lets a paused music app resume. Passing `false` leaves the
    /// user's music stopped with no indication that it can be restarted, which is
    /// the kind of thing that reads as the app being broken.
    public static func deactivate(notifyOthers: Bool = true) throws {
        try AVAudioSession.sharedInstance().setActive(
            false,
            options: notifyOthers ? [.notifyOthersOnDeactivation] : []
        )
    }

    /// Options implied by a policy.
    ///
    /// `.playback` and `.playAndRecord` both ignore the silent switch by
    /// definition, so `playsThroughSilentSwitch` selects the *category* rather than
    /// an option — `.ambient` is the category that obeys it.
    static func options(for policy: AudioSessionPolicy) -> AVAudioSession.CategoryOptions {
        var options: AVAudioSession.CategoryOptions = []
        switch policy.sharing {
        case .exclusive: break
        case .mixWithOthers: options.insert(.mixWithOthers)
        case .duckOthers: options.insert(.duckOthers)
        }
        if policy.recordsInput {
            // Without this a voiceover session routes playback to the receiver
            // rather than the speaker, which sounds like the volume broke.
            options.insert(.defaultToSpeaker)
            options.insert(.allowBluetooth)
        }
        return options
    }

    // MARK: - Route

    /// Where audio is currently going.
    public enum Route: Sendable, Equatable {
        /// The built-in speaker. Recording here captures playback as well as the
        /// voice, so a voiceover made on speaker has the music baked into it twice.
        case speaker
        /// Wired headphones. Latency is negligible.
        case wired
        /// Bluetooth. Adds 150–200 ms round trip — see ``RecordingLatency``.
        case bluetooth
        /// Anything else — AirPlay, CarPlay, a USB interface.
        case other
    }

    /// The current output route.
    ///
    /// Worth checking before recording a voiceover. On ``Route/speaker`` the
    /// microphone hears the playback too, so the take arrives with the music
    /// already in it — and no amount of latency compensation fixes that.
    public static var currentRoute: Route {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        guard let port = outputs.first else { return .other }
        switch port.portType {
        case .builtInSpeaker, .builtInReceiver:
            return .speaker
        case .headphones, .usbAudio:
            return .wired
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return .bluetooth
        default:
            return .other
        }
    }

    /// Whether recording on the current route will capture playback through the
    /// microphone.
    ///
    /// A host can use this to suggest headphones before a take rather than after
    /// listening to one with the backing track bleeding into it.
    public static var recordingWouldCapturePlayback: Bool {
        currentRoute == .speaker
    }

    // MARK: - Interruptions

    /// What happened to the session.
    public enum Interruption: Sendable, Equatable {
        /// Audio was taken away — a call, Siri, another app.
        case began
        /// The interruption ended. `shouldResume` is the system's opinion on
        /// whether playback may restart; ignoring it and resuming anyway is how an
        /// app ends up talking over a phone call.
        case ended(shouldResume: Bool)
    }

    /// Interruptions, as they happen.
    ///
    /// ```swift
    /// for await interruption in AudioSession.interruptions {
    ///     switch interruption {
    ///     case .began: player.pause()
    ///     case .ended(let shouldResume) where shouldResume: player.play()
    ///     case .ended: break
    ///     }
    /// }
    /// ```
    public static var interruptions: AsyncStream<Interruption> {
        AsyncStream { continuation in
            let observer = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: nil
            ) { note in
                guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                switch type {
                case .began:
                    continuation.yield(.began)
                case .ended:
                    let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
                    continuation.yield(.ended(shouldResume: options.contains(.shouldResume)))
                @unknown default:
                    break
                }
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    #endif
}
