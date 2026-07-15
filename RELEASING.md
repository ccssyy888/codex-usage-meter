# Release checklist

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Update the version, download links, and release notes in both README files and `CHANGELOG.md`.
3. Run `swift run --disable-sandbox CodexMeterCoreTests`.
4. Run `./scripts/package_release.sh`.
5. Verify the generated ZIP and SHA-256 file in `dist/`, then launch both the arm64 and x86_64 slices (Rosetta is acceptable; a second Mac is better).
6. Create a GitHub release and attach both files.
7. If the build is not notarized, mark that clearly in the release notes and link to the Gatekeeper instructions in the README.

## Signing and notarization

Without an Apple Developer certificate, the script creates an ad-hoc signed build. It can be published directly, but downloaded copies will trigger a macOS Gatekeeper warning and users must approve the app manually in Privacy & Security settings.

Developer ID signing and notarization are optional for this project. If they are added later, set the Developer ID identity for the build:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
  ./scripts/package_release.sh
```

Then submit the ZIP with `notarytool`, wait for acceptance, staple the ticket to the `.app`, and package it again. Do not store certificates, passwords, API keys, or notarization credentials in this repository.

The bundle identifier is `io.github.ccssyy888.CodexUsageMeter`, and the project is distributed under the MIT License.
