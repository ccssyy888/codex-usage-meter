# Changelog

## 0.2.0 — 2026-09-13

- Evaporate small grains upward from the menu bar badge while a local Codex task is in progress; stop when the task completes or is interrupted.
- Detect task lifecycle events in session files held open for writing by live Codex processes, checking once per second. Support overlapping tasks and remove activity when the writer exits.
- Read lifecycle fields locally without storing or uploading message content; do not traverse session history directories. Update privacy documentation for this additional data source.
- Enlarge evaporating grains to 1.8–2.6 points, retain their contrast through most of the upward travel, and reserve a fixed 29-point icon width for menu-bar visibility. Keep quota digits legible, stop the animation timer when idle, and respect macOS Reduce Motion.
- Skip content reads for unchanged files. Open activity files read-only without following leaf symlinks, and reject special files or files owned by another user.
- Add `--demo --demo-activity` for an animation preview without running real tasks or consuming tokens.

## 0.1.6

- Disable remote control before the quota-only app-server starts, including on Codex CLI versions where the legacy `remote_control` feature flag has been removed.

## 0.1.5

- Explicitly disable Codex remote control in the quota-only app-server launched by the meter, preventing it from competing with ChatGPT's remote connection.
- Add regression coverage for the isolated app-server launch arguments.

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
