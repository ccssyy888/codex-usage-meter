# Changelog

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
