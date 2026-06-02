# XcodeBar

XcodeBar is a macOS menu bar and desktop utility for managing local Apple/Xcode projects, Git branches, and Git worktrees.

## Features

- macOS menu bar entry with configurable label content.
- Main project list window grouped by scan folder, custom group, or Git worktree.
- Settings panel for scan folders, menu bar sections, menu preview, default open target, scripts, and scan logs.
- Scans `.xcworkspace`, `.xcodeproj`, `Package.swift`, and `Podfile`.
- Prefers `.xcworkspace` over `.xcodeproj` when both exist in one project directory.
- Ignores `Pods` and Example-like folders by default and exposes per-scan-folder toggles for them.
- Supports an optional per-scan-folder project name/path regular expression filter. Empty regex means no project filtering.
- Ignores common generated/vendor folders by default, including `DerivedData`, `Carthage`, `.build`, `node_modules`, `vendor`, and `.git`.
- Detects Git branch, Git worktree metadata, and Xcode schemes.
- Scans hidden worktree folders such as `.worktrees` while still ignoring `.git`.
- Opens the current worktree path, not the main repository path.
- Supports opening with Xcode, Finder, Terminal, VS Code, and Cursor.
- Preset scripts: `pod install`, `git pull`, `git status`, and `open in Terminal`.
- Script execution can require confirmation and shows stdout, stderr, exit code, and duration.
- Scan logs support `Info`, `Warning`, and `Error` levels. The default view is `Warning`.

## Build

```bash
swift build
```

## Run

```bash
swift run XcodeBar
```

## Scan Configuration

Each scan folder can configure:

- Display name, path, and group name.
- Recursive scanning.
- Ignore `Pods`.
- Ignore Example-like folders.
- Ignore common generated/vendor folders.
- Optional regular expression filter across project name and path. It is applied before Git and scheme metadata parsing for better scan performance.

Use `Info` log level when debugging scan results. It shows scan options, candidate project counts, and filtered project counts.

## Release

Create and push a version tag to build a DMG and publish it to GitHub Releases:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow builds `XcodeBar.app`, ad-hoc signs it, packages it as a DMG, and uploads the DMG to the matching GitHub Release.

You can also build a local DMG:

```bash
scripts/package-dmg.sh 0.1.0
```

The app stores settings in:

```text
~/Library/Application Support/XcodeBar/settings.json
```

Scanned projects are cached in:

```text
~/Library/Application Support/XcodeBar/projects-cache.json
```

## Notes

This repository is currently implemented as a Swift Package executable using SwiftUI and AppKit. It can be converted into a signed `.app` bundle or Xcode project later without changing the scanner, persistence, or UI model structure.

## License

XcodeBar is released under the MIT License. See [LICENSE](LICENSE).
