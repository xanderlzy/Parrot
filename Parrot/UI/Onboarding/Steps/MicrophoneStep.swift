import SwiftUI

struct MicrophoneStep: View {
    let next: () -> Void
    @State private var granted = Permissions.microphone
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        StepLayout(title: "Let Parrot hear you",
                   message: "Parrot listens only while you hold the dictation key, and the audio never leaves this Mac.") {
            if granted { DoneBadge(text: "Microphone allowed") }
        } actions: {
            if granted {
                PrimaryButton(title: "Continue", action: next)
            } else {
                PrimaryButton(title: "Allow microphone") {
                    Task {
                        if await Permissions.requestMicrophone() { update(true) }
                        else { Permissions.openSettings(.microphone) }
                    }
                }
            }
        }
        .onReceive(poll) { _ in if Permissions.microphone != granted { update(Permissions.microphone) } }
    }

    private func update(_ value: Bool) {
        withAnimation(Motion.fluid) { granted = value }
        if value { DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: next) }
    }
}
