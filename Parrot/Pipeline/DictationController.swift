import AppKit
import AVFoundation
import Observation
import os

protocol AudioSource: AnyObject {
    var levels: AsyncStream<Float> { get }
    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws
    @discardableResult func stop() -> TimeInterval
}
extension AudioCapture: AudioSource {}

struct PolishOutcome: Equatable, Sendable {
    var text: String
    var usedModel: Bool
    var modelUnavailable: Bool
}

protocol Polishing: Sendable {
    func polish(_ raw: String) async -> PolishOutcome
}

protocol DictationSink: AnyObject {
    func record(raw: String, final: String, duration: TimeInterval, appName: String?)
}

enum Sound: Sendable { case start, stop }
protocol SoundPlaying { func play(_ s: Sound) }

extension Notification.Name {
    static let parrotOpenSettings = Notification.Name("ParrotOpenSettings")
}

/// Orchestrates one dictation: hotkey → microphone → transcriber → polisher → paste → history.
@MainActor @Observable
final class DictationController {
    private(set) var pill: PillState = .hidden
    private(set) var level: Float = 0
    private(set) var aiUnavailableNudge = false

    static let copiedMessage = "Copied — press ⌘V"
    static let emptyMessage = "Didn't catch that"
    static let micMessage = "Parrot needs microphone access"

    @ObservationIgnored private let audio: AudioSource
    @ObservationIgnored private let makeTranscriber: () -> Transcriber
    @ObservationIgnored private let polisher: Polishing
    @ObservationIgnored private let inserter: TextInserter
    @ObservationIgnored private let sink: DictationSink
    @ObservationIgnored private let sounds: SoundPlaying
    @ObservationIgnored private let frontmostAppName: () -> String?
    @ObservationIgnored private let ensureMicrophone: () async -> Bool

    private struct Session {
        let id = UUID()
        let transcriber: Transcriber
        let appName: String?
        let feed: BufferFeed
    }
    @ObservationIgnored private var session: Session?
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored private var queueTail: Task<Void, Never>?

    init(audio: AudioSource, transcriber: @escaping () -> Transcriber, polisher: Polishing,
         inserter: TextInserter, sink: DictationSink, sounds: SoundPlaying,
         frontmostAppName: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.localizedName },
         ensureMicrophone: @escaping () async -> Bool = DictationController.defaultEnsureMicrophone) {
        self.audio = audio
        self.makeTranscriber = transcriber
        self.polisher = polisher
        self.inserter = inserter
        self.sink = sink
        self.sounds = sounds
        self.frontmostAppName = frontmostAppName
        self.ensureMicrophone = ensureMicrophone
        let levels = audio.levels
        Task { [weak self] in
            for await value in levels { self?.level = value }
        }
    }

    var isRecording: Bool { session != nil }

    /// Serializes hotkey actions so a quick release can't overtake a slow start.
    func enqueue(_ action: HotkeyAction) {
        let previous = queueTail
        queueTail = Task { [weak self] in
            await previous?.value
            await self?.handle(action)
        }
    }

    func handle(_ action: HotkeyAction) async {
        switch action {
        case .start: await start()
        case .lock: if session != nil { pill = .listening(locked: true) }
        case .commit: await commit()
        case .cancel: await cancel()
        }
    }

    private func start() async {
        guard session == nil else { return }
        guard await ensureMicrophone() else {
            show(Self.micMessage)
            NotificationCenter.default.post(name: .parrotOpenSettings, object: nil)
            return
        }
        let transcriber = makeTranscriber()
        let feed = BufferFeed()
        let s = Session(transcriber: transcriber, appName: frontmostAppName(), feed: feed)
        session = s
        messageTask?.cancel()
        sounds.play(.start)
        pill = .listening(locked: false)
        do {
            // Capture immediately so the first word isn't lost while the engine spins up.
            try audio.start { buffer in feed.push(buffer) }
            try await transcriber.begin()
            feed.attach(transcriber)
        } catch {
            if session?.id == s.id {
                session = nil
                audio.stop()
                await transcriber.cancel()
                show("Couldn't start listening")
            }
        }
    }

    private func commit() async {
        guard let s = session else { return }
        session = nil
        let duration = audio.stop()
        sounds.play(.stop)
        pill = .polishing
        let raw = ((try? await s.transcriber.finish()) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { show(Self.emptyMessage); return }
        let outcome = await polisher.polish(raw)
        aiUnavailableNudge = outcome.modelUnavailable
        let result = await inserter.insert(outcome.text)
        sink.record(raw: raw, final: outcome.text, duration: duration, appName: s.appName)
        if result == .copiedOnly { show(Self.copiedMessage) } else { pill = .hidden }
    }

    private func cancel() async {
        guard let s = session else { pill = .hidden; return }
        session = nil
        audio.stop()
        await s.transcriber.cancel()
        pill = .hidden
    }

    private func show(_ message: String) {
        pill = .message(message)
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled, let self, self.pill == .message(message) else { return }
            self.pill = .hidden
        }
    }

    nonisolated static func defaultEnsureMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
            return false   // this press is spent on the prompt; the next one records
        default: return false
        }
    }
}

/// Holds microphone buffers until the transcriber is ready, then streams straight through.
final class BufferFeed: @unchecked Sendable {
    private struct State { var backlog: [AVAudioPCMBuffer] = []; var target: Transcriber? }
    private let lock = OSAllocatedUnfairLock(uncheckedState: State())

    func push(_ buffer: AVAudioPCMBuffer) {
        lock.withLockUnchecked { state in
            if let target = state.target { target.append(buffer) } else { state.backlog.append(buffer) }
        }
    }

    func attach(_ transcriber: Transcriber) {
        lock.withLockUnchecked { state in
            state.backlog.forEach(transcriber.append)
            state.backlog.removeAll()
            state.target = transcriber
        }
    }
}
