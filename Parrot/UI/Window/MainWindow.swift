import AppKit
import SwiftUI
import SwiftData

enum MainTab: String, CaseIterable, Identifiable {
    case home, history, settings
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@MainActor @Observable
final class AppNavigation {
    var tab: MainTab = .home
}

/// Owns the single main window. Parrot shows a Dock icon only while it's open.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    let navigation = AppNavigation()
    private var window: NSWindow?
    private let makeContent: (AppNavigation) -> AnyView

    init(makeContent: @escaping (AppNavigation) -> AnyView) {
        self.makeContent = makeContent
    }

    var isVisible: Bool { window?.isVisible ?? false }
    var windowFrame: NSRect? { window?.frame }

    func show(_ tab: MainTab? = nil) {
        if let tab { navigation.tab = tab }
        let window = self.window ?? build()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func close() { window?.performClose(nil) }

    private func build() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
                         styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 720, height: 520)
        w.title = "Parrot"
        let host = NSHostingView(rootView: makeContent(navigation))
        // The window owns its size. Left on, SwiftUI resizes it to the content's ideal size,
        // which for flexible onboarding pages is thousands of points tall (off-screen buttons).
        host.sizingOptions = []
        w.contentView = host
        w.center()
        w.delegate = self
        return w
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

/// Onboarding until it's finished, then the main window.
struct RootView: View {
    let env: AppEnvironment
    let navigation: AppNavigation
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        ZStack {
            if onboardingComplete {
                MainWindow(env: env, navigation: navigation).transition(.opacity)
            } else {
                OnboardingView(env: env) {
                    withAnimation(Motion.gentle) { onboardingComplete = true }
                    navigation.tab = .home
                    env.window.close()
                }
                .transition(.opacity)
            }
        }
    }
}

/// Sidebar + content for Home / History / Settings.
struct MainWindow: View {
    let env: AppEnvironment
    @Bindable var navigation: AppNavigation
    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.fg(0.06)).frame(width: 1)
            ZStack {
                switch navigation.tab {
                case .home: HomeView(env: env)
                case .history: HistoryView(env: env)
                case .settings: SettingsView(env: env)
                }
            }
            .id(navigation.tab)
            .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 10)), removal: .opacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 56).padding(.horizontal, 40).padding(.bottom, 28)
        }
        .animation(Motion.fluid, value: navigation.tab)
        .foregroundStyle(Theme.fg())
        .background(Theme.bg())
        .ignoresSafeArea()
        .modelContainer(env.history.container)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ParrotMark().padding(.bottom, 28)
            ForEach(MainTab.allCases) { tab in
                Button { navigation.tab = tab } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            if navigation.tab == tab {
                                Capsule().fill(Theme.fg()).frame(width: 2, height: 14)
                                    .matchedGeometryEffect(id: "indicator", in: indicator)
                            }
                        }
                        .frame(width: 2)
                        Text(tab.title)
                            .font(.system(size: 13, weight: navigation.tab == tab ? .semibold : .regular))
                            .foregroundStyle(Theme.fg(navigation.tab == tab ? 1 : 0.45))
                    }
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("v\(Bundle.main.shortVersion)")
                .font(Theme.Font.caption).foregroundStyle(Theme.fg(0.3))
        }
        .padding(.top, 56).padding(.horizontal, 24).padding(.bottom, 24)
        .frame(width: 176, alignment: .leading)
    }
}

/// Wordmark: three bars and the name.
struct ParrotMark: View {
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach([6.0, 12.0, 8.0], id: \.self) { h in
                    Capsule().fill(Theme.fg()).frame(width: 2.5, height: h)
                }
            }
            Text("Parrot").font(.system(size: 15, weight: .semibold)).tracking(-0.2)
        }
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }
}
