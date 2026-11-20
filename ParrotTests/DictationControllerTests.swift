import Testing
import AppKit
import AVFoundation
@testable import Parrot

// MARK: - Fakes

final class FakeAudio: AudioSource {
    let levels: AsyncStream<Float>
    init() { levels = AsyncStream { _ in } }
    var started = false
    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws { started = true }
    func stop() -> TimeInterval { started = false; return 2.5 }
}

final class FakeTranscriber: Transcriber, @unchecked Sendable {
    var transcript: String
    var cancelled = false
    init(_ transcript: String) { self.transcript = transcript }
    func prepare() async throws {}
    var isReady: Bool { get async { true } }
    func begin() async throws {}
    func append(_ buffer: AVAudioPCMBuffer) {}
    func finish() async throws -> String { transcript }
    func cancel() async { cancelled = true }
}

struct UppercasePolisher: Polishing {
    func polish(_ raw: String) async -> PolishOutcome {
        PolishOutcome(text: raw.uppercased(), usedModel: true, modelUnavailable: false)
    }
}

final class FakeSink: DictationSink {
    var records: [(raw: String, final: String, duration: TimeInterval, app: String?)] = []
    func record(raw: String, final: String, duration: TimeInterval, appName: String?) {
        records.append((raw, final, duration, appName))
    }
}

final class FakeSounds: SoundPlaying {
    var played: [Sound] = []
    func play(_ s: Sound) { played.append(s) }
}

// MARK: - Tests

@MainActor
struct DictationControllerTests {
    struct Rig {
        let controller: DictationController
        let transcriber: FakeTranscriber
        let sink: FakeSink
        let sounds: FakeSounds
        let pasted: () -> [String]
    }

    func rig(transcript: String = "hello there", canPaste: Bool = true) -> Rig {
        let pb = NSPasteboard(name: .init("parrot.test.\(UUID())"))
        final class Box { var pasted: [String] = [] }
        let box = Box()
        let inserter = TextInserter(pasteboard: pb, canPaste: { canPaste },
                                    postPaste: { box.pasted.append(pb.string(forType: .string) ?? "") },
                                    restoreDelay: .zero)
        let t = FakeTranscriber(transcript)
        let sink = FakeSink(), sounds = FakeSounds()
        let c = DictationController(audio: FakeAudio(), transcriber: { t }, polisher: UppercasePolisher(),
                                    inserter: inserter, sink: sink, sounds: sounds,
                                    frontmostAppName: { "TextEdit" }, ensureMicrophone: { true })
        return Rig(controller: c, transcriber: t, sink: sink, sounds: sounds, pasted: { box.pasted })
    }

    @Test func holdFlowInsertsPolishedText() async {
        let r = rig()
        await r.controller.handle(.start)
        #expect(r.controller.pill == .listening(locked: false))
        await r.controller.handle(.commit)
        #expect(r.pasted() == ["HELLO THERE"])
        #expect(r.sink.records.count == 1)
        #expect(r.sink.records.first?.raw == "hello there")
        #expect(r.sink.records.first?.final == "HELLO THERE")
        #expect(r.sink.records.first?.app == "TextEdit")
        #expect(r.sounds.played == [.start, .stop])
        #expect(r.controller.pill == .hidden)
    }

    @Test func emptyTranscriptDoesNothing() async {
        let r = rig(transcript: "  ")
        await r.controller.handle(.start)
        await r.controller.handle(.commit)
        #expect(r.pasted().isEmpty)
        #expect(r.sink.records.isEmpty)
        #expect(r.controller.pill == .message("Didn't catch that"))
    }

    @Test func cancelDiscards() async {
        let r = rig()
        await r.controller.handle(.start)
        await r.controller.handle(.cancel)
        #expect(r.transcriber.cancelled)
        #expect(r.pasted().isEmpty)
        #expect(r.sink.records.isEmpty)
        #expect(r.controller.pill == .hidden)
        await r.controller.handle(.commit)   // stray commit after cancel is ignored
        #expect(r.pasted().isEmpty)
    }

    @Test func lockUpdatesPill() async {
        let r = rig()
        await r.controller.handle(.start)
        await r.controller.handle(.lock)
        #expect(r.controller.pill == .listening(locked: true))
    }

    @Test func secureInputCopiesOnly() async {
        let r = rig(canPaste: false)
        await r.controller.handle(.start)
        await r.controller.handle(.commit)
        #expect(r.pasted().isEmpty)
        #expect(r.controller.pill == .message("Copied — press ⌘V"))
        #expect(r.sink.records.count == 1)
    }

    @Test func missingMicrophoneShowsMessage() async {
        let pb = NSPasteboard(name: .init("parrot.test.\(UUID())"))
        let t = FakeTranscriber("hi")
        let c = DictationController(audio: FakeAudio(), transcriber: { t }, polisher: UppercasePolisher(),
                                    inserter: TextInserter(pasteboard: pb, canPaste: { true }, postPaste: {}, restoreDelay: .zero),
                                    sink: FakeSink(), sounds: FakeSounds(),
                                    frontmostAppName: { nil }, ensureMicrophone: { false })
        await c.handle(.start)
        #expect(c.pill == .message("Parrot needs microphone access"))
    }
}
