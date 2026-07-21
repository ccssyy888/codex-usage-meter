# Changelog

## 0.1.4

- Replace the hexagonal quota tank and separate percentage label with one compact six-lobed menu bar badge.
- Show the remaining five-hour quota as a tightly spaced cut-out number inside the badge, reducing menu bar width while keeping the value visible at a glance.

## 0.1.3

- Replace the static menu bar mark with a compact hexagonal quota tank that fills from bottom to top as the five-hour allowance changes.
- Keep unavailable quota data visually distinct with an empty template icon that adapts cleanly to macOS menu bar appearances.

## 0.1.2

- Rename the Simplified Chinese reset-credit section to “额度重置” and use “次” consistently for its count and item labels.
- Recover more reliably when the Codex app-server process terminates, without scheduling duplicate reconnect paths.
- Refresh the English and Simplified Chinese product screenshots and polish the project documentation.
- Add a release-synchronization policy and stronger post-publish verification steps.

## 0.1.1

- Add prominent macOS download and checksum links to both README files.
- Document how to open the non-notarized build using macOS Privacy & Security settings.
- Treat invalid negative reset-credit counts as zero instead of constructing invalid placeholder rows.
- Redact credentials embedded in quoted JSON diagnostics.
- Produce a cleaner universal ZIP and verify the packaged app and checksum during CI.

## 0.1.0

- Show five-hour and weekly Codex quota in the macOS menu bar.
- List every available reset credit with its own expiry time.
- Read data through the local Codex app-server without parsing credentials or log files.
- Support English and Simplified Chinese.
- Reconnect automatically after app-server interruptions.
