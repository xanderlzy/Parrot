import SwiftUI

struct AccessibilityStep: View {
    let env: AppEnvironment
    let next: () -> Void
    @State private var granted = Permissions.accessibility
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        StepLayout(title: "Let Parrot type for you",
                   message: "Accessibility access lets Parrot notice the dictation key and paste your words where the cursor is. Turn on Parrot in the list that opens.") {
            if granted { DoneBadge(text: "Accessibility allowed") }
        } actions: {
            if granted {
                PrimaryButton(title: "Continue", action: next)
            } else {
                PrimaryButton(title: "Open Accessibility Settings") {
                    Permissions.promptAccessibility()
                    Permissions.openSettings(.accessibility)
                }
            }
        }
        .onReceive(poll) { _ in
            guard Permissions.accessibility, !granted else { return }
            env.startHotkeys()
            withAnimation(Motion.fluid) { granted = true }
            // Bring Parrot back to the front after the user flips the switch in System Settings.
            env.window.show()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: next)
        }
    }
}
