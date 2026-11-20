import Testing
@testable import Parrot

struct OnboardingFlowTests {
    @Test func fullOrderForFn() {
        #expect(OnboardingFlow.steps(hotkey: .fn) == [
            .welcome, .microphone, .accessibility, .speechModel, .appleIntelligence,
            .globeKey, .practice, .tryIt, .finish,
        ])
    }

    @Test func globeStepOnlyForFn() {
        #expect(!OnboardingFlow.steps(hotkey: .rightOption).contains(.globeKey))
        #expect(OnboardingFlow.steps(hotkey: .fn).contains(.globeKey))
    }

    @Test func nextAndBackStayInBounds() {
        var flow = OnboardingFlow(hotkey: .rightCommand)
        #expect(flow.current == .welcome)
        #expect(!flow.canGoBack)
        flow.back()
        #expect(flow.current == .welcome)
        for _ in 0..<20 { flow.next() }
        #expect(flow.current == .finish)
        #expect(flow.isLast)
        flow.back()
        #expect(flow.current == .tryIt)
    }

    @Test func movingForwardSetsDirection() {
        var flow = OnboardingFlow(hotkey: .fn)
        flow.next()
        #expect(flow.forward)
        flow.back()
        #expect(!flow.forward)
    }

    @Test func progressFraction() {
        var flow = OnboardingFlow(hotkey: .fn)
        #expect(flow.index == 0)
        flow.next()
        #expect(flow.index == 1)
        #expect(flow.count == 9)
    }
}
