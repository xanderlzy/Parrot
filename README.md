# Parrot

> **Parrot has moved into [Sidekick](https://github.com/xanderlzy/sidekick).**
> It lives on there as the **Dictation** tool: the same hold-a-key, speak, clean-text experience, alongside other small tools for your Mac.
> Parrot won't get further updates. [Download Sidekick](https://github.com/xanderlzy/sidekick/releases/latest), turn on Dictation, and your Parrot history and settings come with you automatically.

Hold a key, speak, and clean text appears wherever you're typing. Parrot runs entirely on your Mac: Apple's on-device speech engine (or optional local Whisper) transcribes, and Apple Intelligence tidies the result. No accounts, and nothing you say leaves your Mac.

**Requirements:** Apple Silicon Mac, macOS 26 or later. Apple Intelligence on for polishing (optional).

## Install

1. Download `Parrot-x.y.z.zip` from the [latest release](https://github.com/xanderlzy/parrot/releases/latest) and unzip it.
2. Drag **Parrot** into your **Applications** folder.
3. Open it. Parrot isn't notarized by Apple, so macOS blocks it the first time:
   open **System Settings › Privacy & Security**, scroll down, and click **Open Anyway** next to the Parrot message.
   (Or in Terminal: `xattr -dr com.apple.quarantine /Applications/Parrot.app`.)
4. Follow the short setup. Parrot updates itself after that.

## Use

- **Hold Fn** (or the key you choose) and talk. Let go to insert.
- **Double-tap** to go hands-free; tap once more to finish. **Esc** cancels.
- Open Parrot from the menu bar to see your history, stats and settings.

## Development

```sh
brew install xcodegen
scripts/make-cert.sh                      # one-time: stable local signing identity
xcodegen && open Parrot.xcodeproj
scripts/test.sh                           # unit + integration tests
scripts/release.sh 0.1.1 "What changed"   # build, sign, publish, update the feed
```
