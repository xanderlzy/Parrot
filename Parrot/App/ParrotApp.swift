import SwiftUI

@main
struct ParrotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Parrot", systemImage: "waveform") {
            Button("Open Parrot…") { AppEnvironment.shared.window.show() }
            Divider()
            Button("Check for Updates…") { AppEnvironment.shared.updater?.checkForUpdates() }
                .disabled(AppEnvironment.shared.updater == nil)
            Divider()
            Button("Quit Parrot") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests host inside the app; don't grab the keyboard or mic there.
        guard NSClassFromString("XCTestCase") == nil else { return }
        let env = AppEnvironment.shared
        env.prepareSpeech()
        env.showPill()
        env.startPruning()
        if !Permissions.accessibility { Permissions.promptAccessibility() }
        env.startHotkeys()
        #if DEBUG
        // Development aid: `open Parrot.app --args -ParrotOpenTab settings`
        if let tab = UserDefaults.standard.string(forKey: "ParrotOpenTab").flatMap(MainTab.init(rawValue:)) {
            env.window.show(tab)
        }
        #endif
    }
}
