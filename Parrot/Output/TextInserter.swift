import AppKit
import Carbon.HIToolbox

/// Every item on a pasteboard, with every type's raw data, so it can be put back exactly.
struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(_ pb: NSPasteboard) -> PasteboardSnapshot {
        let items = (pb.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
        return PasteboardSnapshot(items: items)
    }

    func restore(to pb: NSPasteboard) {
        pb.clearContents()
        guard !items.isEmpty else { return }
        pb.writeObjects(items.map { types in
            let item = NSPasteboardItem()
            for (type, data) in types { item.setData(data, forType: type) }
            return item
        })
    }
}

enum InsertResult: Equatable, Sendable { case pasted, copiedOnly }

/// Puts text into the focused app by briefly borrowing the clipboard and sending ⌘V,
/// then restoring whatever the clipboard held before.
@MainActor
final class TextInserter {
    /// Marks our temporary clipboard write so clipboard managers ignore it.
    static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private let pasteboard: NSPasteboard
    private let canPaste: () -> Bool
    private let postPaste: () -> Void
    private let restoreDelay: Duration

    init(pasteboard: NSPasteboard = .general,
         canPaste: @escaping () -> Bool = TextInserter.defaultCanPaste,
         postPaste: @escaping () -> Void = TextInserter.postCommandV,
         restoreDelay: Duration = .milliseconds(250)) {
        self.pasteboard = pasteboard
        self.canPaste = canPaste
        self.postPaste = postPaste
        self.restoreDelay = restoreDelay
    }

    func insert(_ text: String) async -> InsertResult {
        guard canPaste() else {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .copiedOnly
        }
        let snapshot = PasteboardSnapshot.capture(pasteboard)
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: Self.transientType)
        pasteboard.writeObjects([item])
        let ourChange = pasteboard.changeCount
        postPaste()
        if restoreDelay > .zero { try? await Task.sleep(for: restoreDelay) }
        // If the user copied something new in the meantime, leave it alone.
        if pasteboard.changeCount == ourChange { snapshot.restore(to: pasteboard) }
        return .pasted
    }

    nonisolated static func defaultCanPaste() -> Bool {
        AXIsProcessTrusted() && !IsSecureEventInputEnabled()
    }

    nonisolated static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
