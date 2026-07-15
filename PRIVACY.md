# Privacy

Codex Usage Meter runs entirely on your Mac.

- It reads quota data from the locally installed `codex app-server --stdio` process.
- It does not read or store `~/.codex/auth.json`.
- It does not include analytics, ads, or third-party tracking.
- It does not send your quota data to the developer or to any additional service.
- It only stores the Codex executable path you select in macOS UserDefaults.

Codex itself may communicate with OpenAI as part of its normal operation. That behavior is controlled by Codex, not by this app.
