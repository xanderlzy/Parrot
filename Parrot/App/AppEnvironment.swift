import AppKit
import SwiftUI
import SwiftData

/// Builds and owns the app's long-lived objects.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let audio = AudioCapture()
    let appleTranscriber = AppleTranscriber()
    let inserter = TextInserter()
    let hotkeys: HotkeyMonitor
    let controller: DictationController
    let stats = StatsStore()
    let history: HistoryStore
    private var pruneTimer: Timer?
    private(set) var pill: PillPresenter?
    private(set) var window: MainWindowController!
    /// Set once Sparkle is wired up (Task 14).
    var updater: Updater?
    let polishClient = SystemModelClient()
    var polishAvailable: Bool { polishClient.isAvailable }
    private var trustPoll: Timer?

    private init() {
        let defaults = UserDefaults.standard
        hotkeys = HotkeyMonitor(key: HotkeyKey(rawValue: defaults.string(forKey: "hotkey") ?? "") ?? .fn)
        let container = (try? HistoryStore.makeContainer())
            ?? (try! ModelContainer(for: DictationRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        history = HistoryStore(container: container, stats: stats, policy: { RetentionPolicy.current() })
        let apple = appleTranscriber
        controller = DictationController(
            audio: audio,
            transcriber: { apple },
            polisher: FoundationPolisher(client: polishClient),
            inserter: inserter,
            sink: history,
            sounds: SystemSounds())
        audio.deviceUID = defaults.string(forKey: "inputDeviceUID")
        let controller = controller
        hotkeys.onAction = { controller.enqueue($0) }
        window = MainWindowController { [unowned self] nav in AnyView(MainWindow(env: self, navigation: nav)) }
        NotificationCenter.default.addObserver(forName: .parrotOpenSettings, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AppEnvironment.shared.window.show(.settings) }
        }
    }

    func setHotkey(_ key: HotkeyKey) {
        hotkeys.key = key
    }

    /// Applies the retention setting now and once a day.
    func startPruning() {
        history.prune()
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.history.prune() }
        }
    }

    func showPill() { if pill == nil { pill = PillPresenter(controller: controller) } }

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
