# Codex Usage Meter

**A tiny, native macOS menu bar meter for Codex usage limits and reset credits.**

[简体中文](README.zh-CN.md)

**[Download v0.1.1 for macOS](https://github.com/ccssyy888/codex-usage-meter/releases/download/v0.1.1/Codex-Usage-Meter-v0.1.1-macOS.zip)** · [Release notes](https://github.com/ccssyy888/codex-usage-meter/releases/tag/v0.1.1) · [SHA-256](https://github.com/ccssyy888/codex-usage-meter/releases/download/v0.1.1/Codex-Usage-Meter-v0.1.1-macOS.zip.sha256)

![Codex Usage Meter showing quota and reset credit expiries](docs/images/overview-en.png)

See what matters without opening another dashboard:

- 5-hour quota directly in the menu bar
- Weekly quota and exact reset times
- Every reset credit listed with its own expiry date
- Automatic refresh and reconnection
- English and Simplified Chinese
- No analytics, ads, account file parsing, or log scraping

Codex Usage Meter talks only to your local `codex app-server --stdio` process. It does **not** read or store `~/.codex/auth.json`.

## Requirements

- macOS 14 or later
- Apple Silicon or Intel Mac
- Codex CLI installed and signed in (tested with `codex-cli 0.144.4`)

## Install

1. [Download the macOS ZIP](https://github.com/ccssyy888/codex-usage-meter/releases/download/v0.1.1/Codex-Usage-Meter-v0.1.1-macOS.zip).
2. Unzip it and move **Codex Usage Meter.app** to Applications.
3. Open the app from Applications.

This build is not notarized. If macOS blocks the first launch, try opening the app once, then go to **System Settings → Privacy & Security → Security** and choose **Open Anyway**. Only bypass this warning if you downloaded the app from this repository and trust it. See [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).

Optional integrity check, run from the folder containing both downloads:

```bash
shasum -a 256 -c Codex-Usage-Meter-v0.1.1-macOS.zip.sha256
```

To build from source:

- Xcode 16 or a Swift 6.0+ toolchain

```bash
swift run --disable-sandbox CodexMeterCoreTests
./scripts/build_app.sh
```

The app is created at `outputs/Codex Usage Meter.app`. If Codex is not found automatically, open the meter menu and choose the `codex` executable manually.

Codex Usage Meter uses the local Codex app-server protocol. New Codex CLI releases may require compatibility updates, so please include your CLI version when reporting a problem.

## Privacy

Everything stays on your Mac. See [PRIVACY.md](PRIVACY.md) for the short, plain-language policy.

## Project status

This is an early, focused utility. Bug reports and small improvements are welcome. See [RELEASING.md](RELEASING.md) for the maintainer release checklist.

## License

[MIT](LICENSE) © 2026 ccssyy888

Codex Usage Meter is an independent, unofficial project. It is not affiliated with or endorsed by OpenAI. “OpenAI” and “Codex” are trademarks of their respective owner.
