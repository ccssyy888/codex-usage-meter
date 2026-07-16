# Project collaboration instructions

## Keep releases synchronized

- Treat changes under `Sources/`, `Resources/`, `Package.swift`, or the build and packaging scripts as app-impacting changes.
- When the user authorizes pushing an app-impacting change, include the release workflow in the same task unless the user explicitly asks to defer it.
- Do not stop after committing or pushing while the public download still points to an older build.
- For each app-impacting release:
  1. Bump `CFBundleShortVersionString` and `CFBundleVersion`.
  2. Update `CHANGELOG.md` and both README download links.
  3. Update product screenshots when visible UI or wording changes.
  4. Run the core tests and build the universal release package.
  5. Verify signing, both architectures, ZIP contents, and SHA-256.
  6. Push the release commit and wait for CI to pass.
  7. Create a new tag and GitHub Release; never replace assets on an existing release.
  8. Download the published assets and verify them again.
- Pure documentation, marketing, or repository-maintenance changes do not require a new app release when they cannot affect the installed product. State that decision explicitly in the handoff.
- Follow `RELEASING.md` for the detailed checklist and preserve unrelated user files or worktree changes.
