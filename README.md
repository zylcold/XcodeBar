# XcodeBar

[中文说明](README.zh-CN.md)

XcodeBar is a macOS menu bar utility for keeping local Apple development projects easy to find, open, and operate. It scans configured folders for Xcode workspaces, Xcode projects, Swift packages, Podfiles, Git branches, Git worktrees, Xcode schemes, and per-project script actions.

The app is built as a Swift Package executable with SwiftUI and AppKit. It targets macOS 13+.

## Highlights

- Menu bar entry with configurable title content and menu sections.
- Desktop project list grouped by scan folder, custom group, or Git worktree.
- Configurable scan folders with recursive scanning, display names, group names, and regex filters.
- Discovery for `.xcworkspace`, `.xcodeproj`, `Package.swift`, and `Podfile`.
- `.xcworkspace` is preferred over `.xcodeproj` when both are found in the same project directory.
- Git branch and worktree metadata detection for each discovered project.
- Xcode scheme discovery from shared and user schemes.
- Hidden worktree folders such as `.worktrees` are scanned; `.git` is still explicitly ignored.
- Built-in filtering for Pods, Example-like folders, and common generated/vendor directories.
- Open projects in Xcode, Finder, Terminal, VS Code, or Cursor.
- Favorite projects, recent projects, quick refresh, scan progress, and scan logs.
- Project-scoped scripts with confirmation prompts and execution result details.

## Build And Run

Build with Swift Package Manager:

```bash
swift build
```

Run the menu bar app:

```bash
swift run XcodeBar
```

The executable is defined in `Package.swift` and lives under `Sources/XcodeBar`.

## App Workflow

1. Add one or more scan folders in Settings.
2. Configure each folder's display name, grouping, recursion, ignore rules, and optional regex filter.
3. Refresh all folders or refresh one folder from the UI.
4. Search, sort, and group discovered projects in the main project list.
5. Open a project with the configured default target or a per-row target.
6. Run project scripts from the project row or menu bar project menu.

## Scan Configuration

Each scan folder supports:

- `displayName`: label shown in the UI.
- `path`: local folder path to scan.
- `groupName`: custom grouping label.
- `projectRegex`: optional case-insensitive regex matched against project name and path.
- `isEnabled`: allows keeping a folder configured but excluded from scans.
- `recursiveScan`: scans nested folders when enabled.
- `detectGitWorktree`: intended worktree detection toggle for the folder.
- `ignorePods`: hides Pods-generated projects and paths under `Pods`.
- `ignoreExamples`: hides folders whose path component contains `example`.
- `ignoreCommonDirectories`: skips common generated/vendor folders.

Common skipped directories include:

```text
DerivedData
Carthage
.build
node_modules
vendor
.git
```

Recursive scanning intentionally does not use `.skipsHiddenFiles`, because Git worktrees are often kept in hidden folders such as `.worktrees`.

## Project Detection

XcodeBar treats a directory as a project candidate when it finds at least one of:

- `.xcworkspace`
- `.xcodeproj`
- `Package.swift`
- `Podfile`

When multiple signals are present in the same root directory, the project type is selected in this order:

1. Workspace
2. Xcode project
3. SwiftPM package
4. Pods/Podfile project

The preferred open path is the workspace path, then the Xcode project path, then the project root.

## Git And Worktrees

For each project, XcodeBar reads Git metadata from the project root:

- current branch, or short commit hash when detached;
- Git root path;
- whether the project is in a linked worktree;
- worktree name;
- main worktree path when available.

Worktrees are kept as distinct project entries. Opening and script execution use the active project/worktree path, not the main repository path.

## Scripts

Preset scripts include:

- `pod install`
- `pod update`
- `swift package resolve`
- `git pull`
- `git status --short --branch`
- `xcodebuild clean`
- `open in Terminal`

Scripts have a scope:

- `Global`
- `Group`
- `Project`
- `Worktree`

Project and worktree scripts are shown beside project rows and project menu items. Scripts may require confirmation before running. Execution records command, working directory, stdout, stderr, exit code, and duration.

## Menu Bar Settings

The menu bar can show:

- icon only;
- icon plus current project;
- icon plus current branch;
- icon plus current worktree;
- a custom combination of project, branch, and worktree.

Menu sections can be toggled independently, including favorites, recent projects, current group, quick scripts, refresh controls, scan status, and the control panel entry. Settings include a preview panel so changes can be checked before relying on the compact menu bar display.

## Data Files

Settings are stored at:

```text
~/Library/Application Support/XcodeBar/settings.json
```

Scanned project cache is stored at:

```text
~/Library/Application Support/XcodeBar/projects-cache.json
```

Model changes should remain backward-compatible with existing JSON files.

## Logs

Scan logs support three levels:

- `Info`
- `Warning`
- `Error`

The default UI filter is `Warning`. Use `Info` when debugging scan behavior; it includes scan options, candidate counts, regex filtering, filtered project counts, and elapsed scan time.

## Release

Create and push a version tag matching `v*`:

```bash
git tag v0.1.0
git push origin v0.1.0
```

`.github/workflows/release.yml` will:

1. Build `XcodeBar` in release mode.
2. Wrap the executable into `XcodeBar.app`.
3. Ad-hoc sign the app.
4. Create a DMG.
5. Upload the DMG to the matching GitHub Release.

Build a local DMG with:

```bash
scripts/package-dmg.sh 0.1.0
```

## Repository Layout

```text
Package.swift
Sources/XcodeBar/
  XcodeBarApp.swift
  AppState.swift
  Models/AppModels.swift
  Services/
    PersistenceStore.swift
    ProjectOpener.swift
    ProjectScanner.swift
    ScriptRunner.swift
    Shell.swift
  Views/
    MenuBarViews.swift
    ProjectListView.swift
    SettingsView.swift
    WindowFocusView.swift
scripts/package-dmg.sh
.github/workflows/release.yml
```

## Development Notes

- Keep scanning logic in `Sources/XcodeBar/Services/ProjectScanner.swift`.
- Keep persistence in `Sources/XcodeBar/Services/PersistenceStore.swift`.
- Keep shared application state in `Sources/XcodeBar/AppState.swift`.
- Keep model defaults and custom `Codable` initializers backward-compatible.
- Avoid clearing user settings or the project cache unless the change explicitly requires it.
- There is currently no dedicated test target; use `swift build` as the baseline validation.

## License

XcodeBar is released under the MIT License. See [LICENSE](LICENSE).
