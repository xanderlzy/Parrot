import SwiftUI

struct FinishStep: View {
    let done: () -> Void
    @State private var launchAtLogin = true

    var body: some View {
        StepLayout(title: "You're all set",
                   message: "Parrot lives in your menu bar. Open it from there any time to see your history and settings.") {
            Toggle(isOn: $launchAtLogin) {
                Text("Launch Parrot at login").font(.system(size: 14))
            }
            .toggleStyle(MonoToggleStyle())
            .frame(maxWidth: 320)
        } actions: {
            PrimaryButton(title: "Done") {
                try? LoginItem.set(launchAtLogin)
                done()
            }
        }
    }
}
