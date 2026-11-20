import SwiftUI

@main
struct ParrotApp: App {
    var body: some Scene {
        MenuBarExtra("Parrot", systemImage: "waveform") {
            Button("Quit Parrot") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
