import SwiftUI

struct SettingsView: View {
    let env: AppEnvironment
    @AppStorage("hotkey") private var hotkey = HotkeyKey.fn.rawValue
    @AppStorage("inputDeviceUID") private var inputDeviceUID = ""
    @AppStorage(SystemSounds.enabledKey) private var soundsEnabled = true
    @AppStorage(RetentionPolicy.storageKey) private var retention = RetentionPolicy.default.rawValue
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var devices = AudioCapture.inputDevices()
    @State private var micGranted = Permissions.microphone
    @State private var axGranted = Permissions.accessibility
    private let permissionPoll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Settings").font(Theme.Font.title)

                section("Dictation") {
                    row("Dictation key", detail: "Hold to talk. Double-tap for hands-free.") {
                        Picker("", selection: $hotkey) {
                            ForEach(HotkeyKey.allCases) { Text($0.displayName).tag($0.rawValue) }
                        }
                        .labelsHidden().fixedSize()
                    }
                    row("Microphone") {
                        Picker("", selection: $inputDeviceUID) {
                            Text("System default").tag("")
                            ForEach(devices) { Text($0.name).tag($0.uid) }
                        }
                        .labelsHidden().fixedSize()
                    }
                    EngineSettings(env: env)
                }

                section("Feedback") {
                    row("Sounds", detail: "A soft click when listening starts and stops.") {
                        Toggle("", isOn: $soundsEnabled).toggleStyle(MonoToggleStyle()).labelsHidden()
                    }
                }

                section("History") {
                    row("Keep history", detail: "Stored only on this Mac. Stats are kept either way.") {
                        Picker("", selection: $retention) {
                            ForEach(RetentionPolicy.allCases) { Text($0.displayName).tag($0.rawValue) }
                        }
                        .labelsHidden().fixedSize()
                    }
                }

                section("Permissions") {
                    row("Microphone", detail: "To hear you while the key is held.") {
                        permissionControl(granted: micGranted) {
                            Task {
                                if await !Permissions.requestMicrophone() { Permissions.openSettings(.microphone) }
                            }
                        }
                    }
                    row("Accessibility", detail: "To notice the dictation key and paste text.") {
                        permissionControl(granted: axGranted) {
                            Permissions.promptAccessibility()
                            Permissions.openSettings(.accessibility)
                        }
                    }
                }

                section("General") {
                    row("Launch at login") {
                        Toggle("", isOn: $launchAtLogin).toggleStyle(MonoToggleStyle()).labelsHidden()
                    }
                    row("Updates", detail: "Version \(Bundle.main.shortVersion)") {
                        Button("Check for updates") { env.updater?.checkForUpdates() }
                            .buttonStyle(MonoButtonStyle())
                            .disabled(env.updater == nil)
                    }
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
        .scrollIndicators(.never)
        .onChange(of: hotkey) { _, new in env.setHotkey(HotkeyKey(rawValue: new) ?? .fn) }
        .onChange(of: inputDeviceUID) { _, new in env.audio.deviceUID = new.isEmpty ? nil : new }
        .onChange(of: retention) { _, _ in env.history.prune() }
        .onChange(of: launchAtLogin) { _, on in
            do { try LoginItem.set(on) } catch { launchAtLogin = LoginItem.isEnabled }
        }
        .onReceive(permissionPoll) { _ in
            micGranted = Permissions.microphone
            axGranted = Permissions.accessibility
        }
        .onAppear { devices = AudioCapture.inputDevices() }
    }

    @ViewBuilder
    private func permissionControl(granted: Bool, grant: @escaping () -> Void) -> some View {
        if granted {
            Label("Allowed", systemImage: "checkmark")
                .font(Theme.Font.caption).foregroundStyle(Theme.fg(0.5))
                .transition(.scale.combined(with: .opacity))
        } else {
            Button("Allow", action: grant).buttonStyle(MonoButtonStyle(prominent: true))
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(text: title).padding(.bottom, 6)
            content()
        }
    }

    private func row<Control: View>(_ title: String, detail: String? = nil,
                                    @ViewBuilder control: () -> Control) -> some View {
        SettingsRow(title: title, detail: detail, control: control())
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var detail: String?
    let control: Control

    init(title: String, detail: String? = nil, control: Control) {
        self.title = title; self.detail = detail; self.control = control
    }

    init(title: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
        self.init(title: title, detail: detail, control: control())
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.Font.body)
                    if let detail {
                        Text(detail).font(Theme.Font.caption).foregroundStyle(Theme.fg(0.45))
                    }
                }
                Spacer()
                control
            }
            .padding(.vertical, 11)
            Hairline()
        }
    }
}

/// Speech engine choice, plus the optional Whisper download.
struct EngineSettings: View {
    let env: AppEnvironment
    @AppStorage(TranscriberKind.storageKey) private var engine = TranscriberKind.apple.rawValue

    private var store: WhisperModelStore { env.whisperModel }
    private var waitingForDownload: Bool { engine == TranscriberKind.whisper.rawValue && !store.isReady }

    var body: some View {
        SettingsRow(title: "Speech engine",
                    detail: waitingForDownload ? "Using Apple until Whisper is downloaded." : "Runs entirely on this Mac.") {
            Picker("", selection: $engine) {
                ForEach(TranscriberKind.allCases) { Text($0.displayName).tag($0.rawValue) }
            }
            .labelsHidden().fixedSize()
        }
        .onChange(of: engine) { _, _ in env.warmUpEngine() }
        .onChange(of: store.state) { _, new in if new == .ready { env.warmUpEngine() } }

        SettingsRow(title: "Whisper model", detail: whisperDetail) {
            switch store.state {
            case .notDownloaded, .failed:
                Button("Download") { store.download() }.buttonStyle(MonoButtonStyle(prominent: true))
            case .downloading(let fraction):
                HStack(spacing: 10) {
                    ProgressBar(fraction: fraction).frame(width: 120)
                    Text("\(Int(fraction * 100))%").font(Theme.Font.caption).monospacedDigit()
                        .foregroundStyle(Theme.fg(0.5)).frame(width: 34, alignment: .trailing)
                }
            case .ready:
                Button("Remove") { store.remove(); env.warmUpEngine() }.buttonStyle(MonoButtonStyle())
            }
        }
        .animation(Motion.fluid, value: store.state)
    }

    private var whisperDetail: String {
        switch store.state {
        case .notDownloaded: "Optional. Often better with accents and jargon. A few hundred MB."
        case .downloading: "Downloading…"
        case .ready: "Downloaded and ready."
        case .failed(let message): message
        }
    }
}

/// Thin ink progress bar.
struct ProgressBar: View {
    let fraction: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.fg(0.12))
                Capsule().fill(Theme.fg()).frame(width: max(4, geo.size.width * min(1, max(0, fraction))))
                    .animation(Motion.snappy, value: fraction)
            }
        }
        .frame(height: 4)
    }
}
