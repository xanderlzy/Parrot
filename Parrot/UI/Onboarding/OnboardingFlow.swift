import Foundation

enum OnboardingStep: Equatable, Sendable {
    case welcome, microphone, accessibility, speechModel, appleIntelligence, globeKey, practice, tryIt, finish
}

/// Pure step sequencing for onboarding.
struct OnboardingFlow {
    private(set) var steps: [OnboardingStep]
    private(set) var index = 0
    private(set) var forward = true

    init(hotkey: HotkeyKey) { steps = Self.steps(hotkey: hotkey) }

    static func steps(hotkey: HotkeyKey) -> [OnboardingStep] {
        var s: [OnboardingStep] = [.welcome, .microphone, .accessibility, .speechModel, .appleIntelligence]
        if hotkey == .fn { s.append(.globeKey) }
        s += [.practice, .tryIt, .finish]
        return s
    }

    var current: OnboardingStep { steps[index] }
    var count: Int { steps.count }
    var canGoBack: Bool { index > 0 }
    var isLast: Bool { index == steps.count - 1 }

    mutating func next() { forward = true; index = min(index + 1, steps.count - 1) }
    mutating func back() { forward = false; index = max(index - 1, 0) }
}
