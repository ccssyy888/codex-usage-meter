# Release checklist

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Run `swift run --disable-sandbox CodexMeterCoreTests`.
3. Run `./scripts/package_release.sh`.
4. Verify the generated ZIP and SHA-256 file in `dist/` on a second Mac.
5. Create a GitHub release and attach both files.

## Signing and notarization

Without an Apple Developer certificate, the script creates an ad-hoc signed build. It is suitable for local testing, but downloaded copies will trigger a macOS Gatekeeper warning.

For a public binary release, set your Developer ID identity for the build:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
  ./scripts/package_release.sh
```

Then submit the ZIP with `notarytool`, wait for acceptance, staple the ticket to the `.app`, and package it again. Do not store certificates, passwords, API keys, or notarization credentials in this repository.

The bundle identifier is `io.github.ccssyy888.CodexUsageMeter`, and the project is distributed under the MIT License.
