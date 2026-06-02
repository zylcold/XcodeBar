# AGENTS.md

## Project

XcodeBar is a macOS SwiftUI/AppKit menu bar utility for scanning local Apple/Xcode projects, Git branches, Git worktrees, Xcode schemes, and script actions.

## Build And Run

Use Swift Package Manager:

```bash
swift build
swift run XcodeBar
```

The app targets macOS 13+ and is currently implemented as a Swift Package executable, not an Xcode project.

## Release

Tag pushes matching `v*` trigger `.github/workflows/release.yml`.

The workflow:

1. Builds `XcodeBar` in release mode.
2. Wraps the executable into `XcodeBar.app`.
3. Ad-hoc signs the app.
4. Creates a DMG.
5. Uploads the DMG to the matching GitHub Release.

Local packaging:

```bash
scripts/package-dmg.sh 0.1.0
```

## App Data

Settings:

```text
~/Library/Application Support/XcodeBar/settings.json
```

Project cache:

```text
~/Library/Application Support/XcodeBar/projects-cache.json
```

## Implementation Notes

- Keep scanning logic in `Sources/XcodeBar/Services/ProjectScanner.swift`.
- Keep persistence in `Sources/XcodeBar/Services/PersistenceStore.swift`.
- Keep shared app state in `Sources/XcodeBar/AppState.swift`.
- Keep model changes backward-compatible with old JSON settings/cache files by using default values in custom `Codable` initializers.
- Per-folder filters currently include Pods, Example-like folders, regex matching, and common generated/vendor directories.
- Do not reintroduce `.skipsHiddenFiles` in recursive scanning; hidden worktree folders such as `.worktrees` must be scanned while `.git` remains explicitly ignored.
- Log levels are `Info`, `Warning`, and `Error`; default UI filter should stay `Warning`.
- Menu bar settings include a preview panel; keep it in sync with `MenuBarSettings`.
- Avoid changing unrelated user settings or clearing the project cache unless explicitly requested.

## UI Guidelines

- Prefer system SF Symbols for compact controls.
- Add `.help(...)` to icon-only buttons.
- Keep menu bar content dense and project-focused.
- Script actions should appear at each project row/menu, not as a single global block.

## License

The project is MIT licensed. Keep `LICENSE` intact unless the owner explicitly requests a license change.
