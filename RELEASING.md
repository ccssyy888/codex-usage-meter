# Release checklist

App-impacting changes and their public download must stay synchronized. A change is app-impacting when it modifies `Sources/`, `Resources/`, `Package.swift`, or the build and packaging scripts. Pure documentation, marketing, and repository-maintenance changes may skip a release when they cannot affect the installed app.

1. Confirm the working tree and keep unrelated files out of the release commit.
2. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
3. Update the version, download links, and release notes in both README files and `CHANGELOG.md`.
4. Update the English and Simplified Chinese product screenshots when visible UI or wording changes.
5. Search for stale version numbers and superseded product wording.
6. Run `swift run --disable-sandbox CodexMeterCoreTests`.
7. Run `./scripts/package_release.sh`.
8. Verify the generated ZIP and SHA-256 file in `dist/`, including:
   - ad-hoc or Developer ID signature validity;
   - `arm64` and `x86_64` slices;
   - packaged version and build number;
   - English and Simplified Chinese localization contents;
   - successful SHA-256 verification.
9. Commit and push the release preparation, then wait for CI on that exact commit to pass.
10. Rebuild the package from the committed source if anything changed after the first package build.
11. Create an annotated version tag on the verified commit and push it.
12. Create a new GitHub release and attach both files. Never replace assets on an existing version.
13. If the build is not notarized, mark that clearly in the release notes and link to the Gatekeeper instructions in the README.
14. Download both published assets from GitHub and verify the checksum, version, architectures, signature, and visible localization again.
15. Confirm the README download links resolve to the newly published assets and that GitHub marks the new version as Latest.

## Signing and notarization

Without an Apple Developer certificate, the script creates an ad-hoc signed build. It can be published directly, but downloaded copies will trigger a macOS Gatekeeper warning and users must approve the app manually in Privacy & Security settings.

Developer ID signing and notarization are optional for this project. If they are added later, set the Developer ID identity for the build:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
  ./scripts/package_release.sh
```

Then submit the ZIP with `notarytool`, wait for acceptance, staple the ticket to the `.app`, and package it again. Do not store certificates, passwords, API keys, or notarization credentials in this repository.

The bundle identifier is `io.github.ccssyy888.CodexUsageMeter`, and the project is distributed under the MIT License.
