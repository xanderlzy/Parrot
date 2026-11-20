import SwiftUI

@main
struct ParrotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Parrot", systemImage: "waveform") {
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
        if !Permissions.accessibility { Permissions.promptAccessibility() }
        env.startHotkeys()
    }
}
