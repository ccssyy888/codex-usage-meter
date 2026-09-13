# Codex Usage Meter

[Website](https://ccssyy888.github.io/codex-usage-meter/)

**A lightweight, native macOS menu bar app dedicated to Codex limits—there when you need it, quiet otherwise.**

[简体中文](README.md)

**[Download v0.2.0 for macOS](https://github.com/ccssyy888/codex-usage-meter/releases/download/v0.2.0/Codex-Usage-Meter-v0.2.0-macOS.zip)** · [Release notes](https://github.com/ccssyy888/codex-usage-meter/releases/tag/v0.2.0) · [SHA-256](https://github.com/ccssyy888/codex-usage-meter/releases/download/v0.2.0/Codex-Usage-Meter-v0.2.0-macOS.zip.sha256)

<p align="center">
  <img src="docs/images/activity-en-v0.2.0.gif" width="600" alt="Particles evaporating upward from the Codex Usage Meter badge while a local task is in progress">
</p>
<p align="center"><sub>Grains evaporate upward while local tasks are in progress and stop when they finish. Actual-size simulated preview with demo data.</sub></p>

<p align="center">
  <img src="docs/images/overview-en-v0.2.0.png" width="320" alt="Codex Usage Meter showing quota and reset credit expiries">
</p>

<p align="center"><sub>Native interface demo render with sample quota and reset-credit data.</sub></p>

When you are deep in a session, the last thing you want is another dashboard. Codex Usage Meter lives quietly in your menu bar and gives you the answer at a glance:

- Glance at your 5-hour quota without leaving the app you are working in
- Keep an eye on weekly usage and exact reset times
- See every reset credit together with its own expiry date
- See particles evaporate upward while a local task runs, returning to a still icon when it finishes
- Stay up to date through automatic refresh and reconnection
- Feel at home in English or Simplified Chinese
- Work with confidence: no analytics, ads, account-file parsing, or conversation uploads

Codex Usage Meter reads quota data from the local Codex app-server it launches, with `remote_control` explicitly disabled so it cannot compete with ChatGPT's remote connection. It does **not** read or store `~/.codex/auth.json`.

## Design principles: lightweight by scope

“Lightweight” here is not just about having fewer features. It means keeping the product boundary, interaction path, configuration, and data access narrow around one job: checking Codex limits at a glance.

- **There when needed, quiet otherwise.** A floating desktop control is easier to notice, but it still occupies the content area when collapsed and can cover code, webpages, or clicks. Quota is not a live market feed, so the app uses a stable menu bar entry with no desktop overlay or Dock icon.
- **Do one job well.** The project focuses on Codex instead of growing into a multi-provider AI console. That narrower scope means fewer choices, a more direct interface, and a clearer maintenance boundary.
- **Enough information at a glance.** The five-hour window, weekly window, exact reset times, and individual reset-credit expiries fit in one small popover—click, check, and keep working.
- **Keep the data path short and explicit.** Quota data travels from the local Codex app-server to the menu bar and stops there. The app does not read `auth.json` or upload quota data to another service. The app additionally reads session files held by live Codex processes to parse task lifecycle fields for its animation.

## Codex Usage Meter or CodexBar?

Codex Usage Meter is not a replacement for [CodexBar](https://github.com/steipete/CodexBar). The two projects choose different boundaries: CodexBar optimizes for breadth, while Codex Usage Meter optimizes for focus.

| | Codex Usage Meter | CodexBar |
| --- | --- | --- |
| Product scope | A small window dedicated to Codex limits | A unified usage and status tool for many AI coding providers |
| Primary information | Five-hour, weekly, and reset-credit limits | Multi-provider limits, resets, spend, status, and more, depending on the provider |
| Data path | Isolated local Codex app-server for quota; local session events for task animation | Provider-specific CLIs, OAuth, APIs, browser sessions, or local files |
| Best fit | You use mainly Codex and want minimal setup and a short path to the answer | You use several AI services and want centralized management and broader capabilities |

If you need a broad AI usage center, CodexBar is the better fit. If you want Codex quota to sit quietly in your Mac menu bar, this project is built around that choice.

## What you need

- macOS 14 or later
- Apple Silicon or Intel Mac
- Codex CLI installed and signed in (quota reads tested with `codex-cli 0.154.0`; task events tested with the desktop app’s bundled `0.154.0-alpha.6.2`)

## Get started

1. [Download the macOS ZIP](https://github.com/ccssyy888/codex-usage-meter/releases/download/v0.2.0/Codex-Usage-Meter-v0.2.0-macOS.zip).
2. Unzip it and move **Codex Usage Meter.app** to Applications.
3. Open the app from Applications.

This build is not notarized. If macOS blocks the first launch, try opening the app once, then go to **System Settings → Privacy & Security → Security** and choose **Open Anyway**. Only bypass this warning if you downloaded the app from this repository and trust it. See [Apple's instructions](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unknown-developer-mh40616/mac).

Optional integrity check, run from the folder containing both downloads:

```bash
shasum -a 256 -c Codex-Usage-Meter-v0.2.0-macOS.zip.sha256
```

To build from source:

- Xcode 16 or a Swift 6.0+ toolchain

```bash
swift run --disable-sandbox CodexMeterCoreTests
./scripts/build_app.sh
```

The app is created at `outputs/Codex Usage Meter.app`. If Codex is not found automatically, open the meter menu and choose the `codex` executable manually.

Task activity animation is available starting with v0.2.0. It checks once per second for `task_started`, `task_complete`, and `turn_aborted` events in session files held open for writing by live Codex processes. Small grains evaporate upward while a task is in progress and stop when every task finishes, is interrupted, or loses its writer. On first encountering a file it establishes the current state; subsequent checks read incrementally only when a file changes. It opens files read-only, accepts only regular files owned by the current user, and rejects leaf symlinks and special files. Session bytes pass through memory but are not saved to disk or uploaded; see [Privacy](PRIVACY.md). It does not traverse history directories.

The animation means a local task is in progress, including tool execution or waiting; it is not a live meter of token generation or billing. Incompatible session formats, unreadable files, and tasks running only on other devices may not animate. Preview with `open -n "outputs/Codex Usage Meter.app" --args --demo --demo-activity`.

Codex Usage Meter uses the local Codex app-server protocol. New Codex CLI releases may require compatibility updates, so please include your CLI version when reporting a problem.

## Private by design

Your usage is yours. Everything stays on your Mac, and the app only remembers the Codex executable you choose. See [PRIVACY.md](PRIVACY.md) for the short, plain-language policy.

## A small project, growing carefully

This project started from a simple wish: make Codex limits easy to understand without getting in the way. It is still early and intentionally focused. If something feels off—or you have a small idea that would make it nicer to use—bug reports and thoughtful improvements are very welcome. See [RELEASING.md](RELEASING.md) for the maintainer release checklist.

## License

[MIT](LICENSE) © 2026 ccssyy888

Codex Usage Meter is an independent, unofficial project. It is not affiliated with or endorsed by OpenAI. “OpenAI” and “Codex” are trademarks of their respective owner.
