import AppKit
import SwiftUI

/// Builds and owns the app's long-lived objects.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let audio = AudioCapture()
    let appleTranscriber = AppleTranscriber()
    let inserter = TextInserter()
    let hotkeys: HotkeyMonitor
    let controller: DictationController
    private var trustPoll: Timer?

    private init() {
        let defaults = UserDefaults.standard
        hotkeys = HotkeyMonitor(key: HotkeyKey(rawValue: defaults.string(forKey: "hotkey") ?? "") ?? .fn)
        let apple = appleTranscriber
        controller = DictationController(
            audio: audio,
            transcriber: { apple },
            polisher: PassthroughPolisher(),
            inserter: inserter,
            sink: NullSink(),
            sounds: NullSounds())
        audio.deviceUID = defaults.string(forKey: "inputDeviceUID")
        let controller = controller
        hotkeys.onAction = { controller.enqueue($0) }
    }

    /// Starts listening for the hotkey once Accessibility is granted.
    func startHotkeys() {
        if (try? hotkeys.start()) != nil { return }
        trustPoll?.invalidate()
        trustPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, (try? self.hotkeys.start()) != nil else { return }
                self.trustPoll?.invalidate()
                self.trustPoll = nil
            }
        }
    }

    func prepareSpeech() {
        let t = appleTranscriber
        Task.detached { try? await t.prepare() }
    }
}

struct PassthroughPolisher: Polishing {
    func polish(_ raw: String) async -> PolishOutcome {
        PolishOutcome(text: raw, usedModel: false, modelUnavailable: false)
    }
}
final class NullSink: DictationSink {
    func record(raw: String, final: String, duration: TimeInterval, appName: String?) {}
}
struct NullSounds: SoundPlaying { func play(_ s: Sound) {} }
