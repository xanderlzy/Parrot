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
    let whisperModel = WhisperModelStore()
    private var whisper: WhisperTranscriber?
    /// While set (onboarding practice), hotkey actions go here instead of starting dictation.
    var hotkeyInterceptor: ((HotkeyAction) -> Void)?
    var keyStateObserver: ((Bool) -> Void)?
    var polishAvailable: Bool { polishClient.isAvailable }
    private var trustPoll: Timer?

    private init() {
        let defaults = UserDefaults.standard
        hotkeys = HotkeyMonitor(key: HotkeyKey(rawValue: defaults.string(forKey: "hotkey") ?? "") ?? .fn)
        let container = (try? HistoryStore.makeContainer())
            ?? (try! ModelContainer(for: DictationRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        history = HistoryStore(container: container, stats: stats, policy: { RetentionPolicy.current() })
        let apple = appleTranscriber
        weak var weakSelf: AppEnvironment?
        controller = DictationController(
            audio: audio,
            transcriber: { weakSelf?.currentTranscriber() ?? apple },
            polisher: FoundationPolisher(client: polishClient),
            inserter: inserter,
            sink: history,
            sounds: SystemSounds())
        audio.deviceUID = defaults.string(forKey: "inputDeviceUID")
        let controller = controller
        hotkeys.onAction = { action in
            if let intercept = weakSelf?.hotkeyInterceptor { intercept(action) } else { controller.enqueue(action) }
        }
        hotkeys.onKeyState = { down in weakSelf?.keyStateObserver?(down) }
        weakSelf = self
        window = MainWindowController { [unowned self] nav in AnyView(RootView(env: self, navigation: nav)) }
        NotificationCenter.default.addObserver(forName: .parrotOpenSettings, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AppEnvironment.shared.window.show(.settings) }
        }
    }

    var selectedEngine: TranscriberKind {
        TranscriberKind(rawValue: UserDefaults.standard.string(forKey: TranscriberKind.storageKey) ?? "") ?? .apple
    }

    var effectiveEngine: TranscriberKind {
        .effective(selected: selectedEngine, whisperReady: whisperModel.isReady)
    }

    func currentTranscriber() -> Transcriber {
        guard effectiveEngine == .whisper, let folder = whisperModel.modelFolder else { return appleTranscriber }
        if let whisper { return whisper }
        let w = WhisperTranscriber(modelFolder: folder)
        whisper = w
        return w
    }

    /// Loads the selected engine's model in the background so the first dictation is quick.
    func warmUpEngine() {
        if effectiveEngine != .whisper { whisper = nil }
        let t = currentTranscriber()
        Task.detached { try? await t.prepare() }
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
        if effectiveEngine == .whisper { warmUpEngine() }
    }
}

struct PassthroughPolisher: Polishing {
    func polish(_ raw: String) async -> PolishOutcome {
        PolishOutcome(text: raw, usedModel: false, modelUnavailable: false)
    }
}
