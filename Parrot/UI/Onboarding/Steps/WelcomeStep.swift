import SwiftUI

struct WelcomeStep: View {
    let next: () -> Void
    var body: some View {
        StepLayout(title: "Speak. Parrot writes.",
                   message: "Hold a key, talk, and clean text appears wherever you're typing. Everything happens on this Mac. Nothing you say leaves it.") {
            AnimatedBars().frame(height: 80)
        } actions: {
            PrimaryButton(title: "Get started", action: next)
        }
    }
}

/// The wordmark's bars, gently "speaking".
struct AnimatedBars: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let envelope = 1 - abs(Double(i) - 3) / 4.5
                    let h = 10 + 60 * envelope * (0.55 + 0.45 * sin(t * 3.1 + Double(i) * 0.9))
                    Capsule().fill(Theme.fg()).frame(width: 6, height: h)
                }
            }
            .frame(height: 80)
        }
    }
}
