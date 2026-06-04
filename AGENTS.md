# AGENTS.md

## Project

XcodeBar is a macOS SwiftUI/AppKit menu bar utility for scanning and operating local Apple/Xcode projects. It discovers Xcode workspaces, Xcode projects, Swift packages, Podfiles, Git branches, Git worktrees, Xcode schemes, and script actions.

The repository is a Swift Package executable, not an Xcode project. The app targets macOS 13+.

## Build And Run

Use Swift Package Manager:

```bash
swift build
swift run XcodeBar
```

There is currently no dedicated test target. For normal changes, run `swift build` at minimum.

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

Do not clear or rewrite user data as a side effect of unrelated changes.

## Ownership Boundaries

- Keep scanning and project discovery logic in `Sources/XcodeBar/Services/ProjectScanner.swift`.
- Keep persistence and app-data paths in `Sources/XcodeBar/Services/PersistenceStore.swift`.
- Keep shared app state, filtering, grouping, favorites, refresh flow, and script dispatch in `Sources/XcodeBar/AppState.swift`.
- Keep project-opening behavior in `Sources/XcodeBar/Services/ProjectOpener.swift`.
- Keep script execution behavior in `Sources/XcodeBar/Services/ScriptRunner.swift` and shell helpers in `Sources/XcodeBar/Services/Shell.swift`.
- Keep Codable model changes in `Sources/XcodeBar/Models/AppModels.swift`.
- Keep menu bar UI in `Sources/XcodeBar/Views/MenuBarViews.swift`.
- Keep main list UI in `Sources/XcodeBar/Views/ProjectListView.swift`.
- Keep settings UI in `Sources/XcodeBar/Views/SettingsView.swift`.

## Model Compatibility

Settings and project cache are JSON files in Application Support. Model changes must remain backward-compatible with old files.

When adding stored properties:

- provide default values;
- update custom `Codable` initializers where present;
- avoid changing raw values for existing enums;
- avoid changing `ProjectItem.id` semantics unless cache migration is handled;
- preserve existing user settings and favorites.

## Scanner Rules

The scanner currently detects:

- `.xcworkspace`
- `.xcodeproj`
- `Package.swift`
- `Podfile`

Workspace detection should remain preferred over Xcode project detection when both exist in one project root.

Per-folder filters include:

- Pods-generated projects;
- Example-like folders;
- project name/path regex;
- common generated/vendor directories.

Common ignored directories include `DerivedData`, `Carthage`, `.build`, `node_modules`, `vendor`, and `.git`.

Important: do not reintroduce `.skipsHiddenFiles` in recursive scanning. Hidden worktree folders such as `.worktrees` must be scanned, while `.git` remains explicitly ignored.

Avoid surfacing dependency noise as primary projects. In Apple/Xcode workspaces, Pods internals and nested `project.xcworkspace` entries inside `.xcodeproj` bundles should stay hidden.

## Git And Worktree Behavior

Worktrees are first-class project identities.

- Preserve per-worktree branch/path display.
- Do not collapse linked worktrees into the main repository item.
- Opening a project should use the current project/worktree path.
- Script execution should use the current project/worktree root unless the script has an explicit working directory.
- Keep Git metadata collection cheap enough for large scan folders.

## Menu Bar Behavior

Menu bar settings include display mode, current project/branch/worktree labels, section toggles, auto-refresh interval, and preview UI.

When changing menu bar settings:

- keep the preview panel in sync with `MenuBarSettings`;
- keep menu content dense and project-focused;
- preserve favorites, recent projects, current group, quick scripts, refresh controls, scan status, and control panel toggles;
- avoid turning the menu into a global script launcher.

## Script Actions

Script actions should appear near project rows and project menu items. A project user should be able to run relevant scripts from the specific project they are looking at.

Preserve confirmation behavior for scripts that require it. Script results should continue to expose command, working directory, stdout, stderr, exit code, and duration.

## Logs

Log levels are:

- `Info`
- `Warning`
- `Error`

The default UI filter should stay `Warning`. `Info` logs are for scan debugging and should remain useful: scan options, candidate counts, regex filtering, filtered counts, and elapsed scan time are valuable.

## UI Guidelines

- Prefer system SF Symbols for compact controls.
- Add `.help(...)` to icon-only buttons.
- Keep menu bar content dense and project-focused.
- Keep settings controls explicit rather than hidden in complex gestures.
- Script actions should appear at each project row/menu, not as a single global block.
- Keep text concise; avoid marketing copy inside the app UI.
- Avoid large decorative layouts. This is an operational utility.

## Validation

Before finishing code changes:

```bash
swift build
```

For scanner changes, manually reason through at least these cases:

- root contains both `.xcworkspace` and `.xcodeproj`;
- project lives under a hidden `.worktrees` folder;
- path contains `Pods`;
- path contains an Example-like component;
- scan folder has an empty regex;
- scan folder has an invalid regex;
- detached Git HEAD.

For persistence/model changes, verify old JSON can still decode through default values.

## License

The project is MIT licensed. Keep `LICENSE` intact unless the owner explicitly requests a license change.
