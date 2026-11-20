# Parrot — design & build plan

## Context
A Wispr Flow–style voice-to-text dictation app for macOS. It's a passion project for the user and a small group of friends, but it should be polished like a real product, with onboarding, auto-updates and refined motion. The aesthetic is minimalist black and white with fluid, dynamic animations. `/Users/xanderlzy/Documents/Parrot` is empty, so this is a greenfield build.

**Key pivot from the original ask:** the user first wanted "link your Claude account". Claude's API can't take audio, and claude.ai Pro/Max subscriptions can't be used by third-party apps; the API is pay-per-use, which the user rejected. **Decision: everything runs on Apple's free on-device stack. No Claude and no accounts.**

## Decisions (user-confirmed)
| Area | Decision |
|---|---|
| Audience | Friends only, polished like a real app |
| Speech → text | Apple on-device engine (SpeechAnalyzer/SpeechTranscriber) by default; **Whisper (WhisperKit, local)** as an optional download in Settings |
| Text polish | **Apple Foundation Models (on-device) only.** Light polish: remove fillers, fix punctuation and capitalization, resolve self-corrections; keep the user's wording |
| No Apple Intelligence | Insert the raw transcript and show a gentle nudge explaining how to enable it |
| Hardware | Apple Silicon only. Minimum macOS 26 |
| Trigger | Hold hotkey (default **Fn**, rebindable) to talk; **double-tap** locks hands-free, tap again to finish |
| Presence | Menu bar icon + floating pill (**bottom center**) + main window opened on demand (no Dock icon unless the window is open) |
| Pill | Black capsule, **white waveform bars** reacting to voice level, morphing to a spinner while polishing |
| Theme | Black/white, **follows system** appearance |
| Window | **Home (stats: words dictated, time saved, streak) + History + Settings** |
| History | Local only; retention chosen by the user (7d / 30d / forever / off), default 30d |
| Features v1 | Dictation + History only (no dictionary, per-app styles or voice edit commands) |
| Language | English only |
| Sounds | Subtle start/stop clicks, on by default, toggleable |
| Launch at login | Offered in onboarding, on by default |
| Signing | No paid Apple Developer account → **stable self-signed certificate** so mic/accessibility permissions survive updates; friends right-click → Open on first launch |
| Updates | **Sparkle 2** with the appcast and builds on **GitHub Releases** |
| Name | Parrot |

## My calls (flag if wrong)
- Native **Swift 6 / SwiftUI**, project generated with **XcodeGen** (`project.yml`). Both are installed, along with Xcode 27.2 and `gh`.
- Not sandboxed (the global hotkey event tap and synthetic paste need it).
- Text insertion: save the clipboard → put the result on it → synthesize ⌘V → restore the clipboard.
- Stats are kept as separate running counters, so they survive history pruning. "Time saved" = words ÷ 40 wpm typing − speaking time.
- Persistence via **SwiftData**; settings via `@AppStorage`.
- Onboarding tells the user to set System Settings › Keyboard › "Press 🌐 key to" → *Do Nothing*, so Fn doesn't open the emoji picker.

## Architecture (`Parrot/` sources)
- `App/ParrotApp.swift`: `MenuBarExtra` + `Window`; switches activation policy (accessory ↔ regular) as the window opens and closes.
- `Input/HotkeyMonitor.swift`: `CGEventTap` on `flagsChanged`/`keyDown`; state machine idle → holding → locked → finishing (double-tap window ~300 ms).
- `Audio/AudioCapture.swift`: `AVAudioEngine` tap → 16 kHz buffers + RMS level stream for the waveform.
- `Transcription/Transcriber.swift` (protocol), `AppleTranscriber.swift` (SpeechAnalyzer + `AssetInventory` model install), `WhisperTranscriber.swift` (WhisperKit SPM, model download with progress).
- `Polish/Polisher.swift`: `SystemLanguageModel.default.availability` check; `LanguageModelSession` with a light-polish instruction prompt; returns raw text on unavailability, error or timeout (~3 s).
- `Output/TextInserter.swift`: clipboard save, paste, restore; requires Accessibility.
- `Pipeline/DictationController.swift`: orchestrates hotkey → capture → transcribe → polish → insert → history/stats; publishes pill state.
- `UI/Pill/PillPanel.swift` (non-activating borderless `NSPanel`, all Spaces, bottom center of the active screen) and `PillView.swift` (Canvas waveform, spring morphs between states: idle, listening, locked, polishing, error).
- `UI/Window/` `HomeView` (large typographic stats), `HistoryView` (search, copy, re-insert, delete), `SettingsView` (hotkey recorder, mic picker, engine + Whisper download, sounds, launch at login, retention, check for updates).
- `UI/Onboarding/`: welcome → microphone → accessibility → speech model install → Apple Intelligence check → Fn/emoji setting → hotkey practice → test dictation → launch at login.
- `Data/` SwiftData `Dictation` model, `StatsStore`, retention pruner (on launch + daily).
- `Design/`: color tokens (pure black and white with opacity steps), typography, shared spring presets, haptic and sound helpers.
- `Updates/`: Sparkle `SPUStandardUpdaterController`; `SUFeedURL` → appcast on GitHub.
- `scripts/`: `make-cert.sh` (one-time self-signed code-signing identity), `release.sh` (bump version → xcodebuild archive → codesign → zip/DMG → Sparkle `sign_update` (EdDSA) → update `appcast.xml` → `gh release create`).

## Build order
1. Write this design to `docs/superpowers/specs/2026-11-20-parrot-design.md`, then produce the detailed implementation plan (writing-plans).
2. Scaffold: `project.yml`, app shell, menu bar, design tokens, git init.
3. Hotkey state machine (unit-tested) → audio capture → Apple transcriber → text insertion. First end-to-end dictation, without polish.
4. Polisher + fallback nudge.
5. Pill overlay and animations.
6. SwiftData history + stats + retention; main window (Home, History, Settings).
7. Whisper optional engine.
8. Onboarding flow.
9. Sparkle, signing cert and release script; first GitHub release.

## Verification
- Unit tests (XCTest/Swift Testing): hotkey state machine (hold, double-tap lock, tap to finish, edge timings), retention pruning, stats math, polisher fallback path, clipboard restore.
- `xcodebuild test` and a build via XcodeGen on every step.
- Manual end-to-end: dictate into TextEdit, Notes, Safari and Messages; check filler removal and self-correction; check the clipboard is restored; toggle Apple Intelligence off → raw text + nudge; switch to Whisper and repeat; light/dark appearance; multi-monitor pill placement.
- Fresh-user run: delete app data, reset TCC (`tccutil reset Microphone/Accessibility com.parrot.app`), run onboarding.
- Updates: release v0.1.0 then v0.1.1 via `release.sh`; confirm Sparkle updates in place and that **permissions persist** (validates the self-signed identity).
