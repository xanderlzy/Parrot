import SwiftUI

/// Full-window first-run flow: one idea per screen, one primary action.
struct OnboardingView: View {
    let env: AppEnvironment
    let done: () -> Void
    @State private var flow: OnboardingFlow
    @AppStorage("hotkey") private var hotkey = HotkeyKey.fn.rawValue

    init(env: AppEnvironment, done: @escaping () -> Void) {
        self.env = env
        self.done = done
        let key = HotkeyKey(rawValue: UserDefaults.standard.string(forKey: "hotkey") ?? "") ?? .fn
        var flow = OnboardingFlow(hotkey: key)
        #if DEBUG
        // Development aid: `open Parrot.app --args -onboardingComplete NO -ParrotOnboardingStep 5`
        for _ in 0..<UserDefaults.standard.integer(forKey: "ParrotOnboardingStep") { flow.next() }
        #endif
        _flow = State(initialValue: flow)
    }

    private var key: HotkeyKey { HotkeyKey(rawValue: hotkey) ?? .fn }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                ParrotMark()
                Spacer()
                if flow.canGoBack && !flow.isLast {
                    Button { withAnimation(Motion.fluid) { flow.back() } } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                            Text("Back")
                        }
                        .font(Theme.Font.caption).foregroundStyle(Theme.fg(0.5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressScale())
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                    .transition(.opacity)
                }
                ProgressDots(count: flow.count, index: flow.index)
            }
            .padding(.bottom, 48)

            ZStack(alignment: .topLeading) {
                step(flow.current)
                    .id(flow.index)
                    .transition(.asymmetric(
                        insertion: .offset(x: flow.forward ? 40 : -40).combined(with: .opacity),
                        removal: .offset(x: flow.forward ? -40 : 40).combined(with: .opacity)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.top, 56).padding(.horizontal, 64).padding(.bottom, 32)
        .foregroundStyle(Theme.fg())
        .background(Theme.bg())
        .ignoresSafeArea()
    }

    private func next() { withAnimation(Motion.fluid) { flow.next() } }

    @ViewBuilder private func step(_ s: OnboardingStep) -> some View {
        switch s {
        case .welcome: WelcomeStep(next: next)
        case .microphone: MicrophoneStep(next: next)
        case .accessibility: AccessibilityStep(env: env, next: next)
        case .speechModel: SpeechModelStep(env: env, next: next)
        case .appleIntelligence: AppleIntelligenceStep(env: env, next: next)
        case .globeKey: GlobeKeyStep(next: next)
        case .practice: PracticeStep(env: env, key: key, next: next)
        case .tryIt: TryItStep(key: key, next: next)
        case .finish: FinishStep(done: done)
        }
    }
}

/// Shared layout for a step: headline, one line of copy, custom content, actions.
struct StepLayout<Content: View, Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(Theme.fg(0.55))
                .frame(maxWidth: 460, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            content.padding(.top, 32)
            Spacer(minLength: 24)
            HStack(spacing: 10) { actions }
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 22).padding(.vertical, 10)
                .foregroundStyle(Theme.bg())
                .background(Capsule().fill(Theme.fg()))
        }
        .buttonStyle(PressScale())
        .keyboardShortcut(.defaultAction)
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// A row confirming something is done, with a checkmark that draws itself in.
struct DoneBadge: View {
    let text: String
    @State private var drawn = false
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.fg()).frame(width: 22, height: 22)
                CheckShape().trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(Theme.bg(), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 10, height: 8)
            }
            .scaleEffect(drawn ? 1 : 0.4)
            Text(text).font(.system(size: 14, weight: .medium))
        }
        .onAppear { withAnimation(Motion.fluid) { drawn = true } }
    }
}

private struct CheckShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.38, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        return p
    }
}

private struct ProgressDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(Theme.fg(i <= index ? 1 : 0.15))
                    .frame(width: i == index ? 18 : 6, height: 6)
            }
        }
        .animation(Motion.fluid, value: index)
    }
}
