# Privacy

Codex Usage Meter runs entirely on your Mac.

- It reads quota data from the locally installed `codex app-server --stdio` process.
- Starting with v0.2.0, the app also inspects live Codex processes and reads session files they hold open for writing to identify task start, completion, and interruption events. It establishes state on first encountering an open file, then checks file metadata once per second. Unchanged files require no content reads; changed files are read incrementally. It opens files read-only, rejects leaf symlinks and non-regular files, and requires the file owner to match the current user. It does not traverse archived or historical session directories.
- Only lifecycle event types and turn IDs are decoded for activity; conversation text and tool output are not saved to disk or uploaded. Session bytes, which can include message text, do pass through process memory during parsing. File offsets, a short numeric change-detection fingerprint, partial records awaiting completion, and activity state exist only in memory.
- It does not read or store `~/.codex/auth.json`.
- It does not include analytics, ads, or third-party tracking.
- It does not send your quota data to the developer or to any additional service.
- It only stores the Codex executable path you select in macOS UserDefaults.

Codex itself may communicate with OpenAI as part of its normal operation. That behavior is controlled by Codex, not by this app.
