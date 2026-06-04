# XcodeBar

[English README](README.md)

XcodeBar 是一个 macOS 菜单栏工具，用来集中管理本地 Apple/Xcode 开发项目。它可以扫描配置的文件夹，识别 Xcode Workspace、Xcode Project、Swift Package、Podfile、Git 分支、Git Worktree、Xcode Scheme，以及每个项目可执行的脚本操作。

当前应用使用 SwiftUI 和 AppKit 实现，是一个 Swift Package 可执行程序，目标平台为 macOS 13+。

## 功能亮点

- 可配置标题内容和菜单区块的 macOS 菜单栏入口。
- 桌面项目列表支持按扫描文件夹、自定义分组或 Git Worktree 分组。
- 扫描文件夹支持递归扫描、显示名称、分组名称和正则过滤。
- 支持识别 `.xcworkspace`、`.xcodeproj`、`Package.swift` 和 `Podfile`。
- 同一项目目录同时存在 `.xcworkspace` 和 `.xcodeproj` 时，优先使用 `.xcworkspace`。
- 为每个项目检测 Git 分支和 Git Worktree 元数据。
- 从共享 Scheme 和用户 Scheme 中发现 Xcode Scheme。
- 会扫描 `.worktrees` 这类隐藏 Worktree 目录，但仍会显式忽略 `.git`。
- 内置 Pods、Example 类目录、常见生成目录和依赖目录过滤。
- 支持用 Xcode、Finder、Terminal、VS Code 或 Cursor 打开项目。
- 支持收藏项目、最近打开项目、快速刷新、扫描进度和扫描日志。
- 支持项目级脚本，包含执行确认和执行结果信息。

## 构建和运行

使用 Swift Package Manager 构建：

```bash
swift build
```

运行菜单栏应用：

```bash
swift run XcodeBar
```

可执行目标定义在 `Package.swift` 中，源码位于 `Sources/XcodeBar`。

## 使用流程

1. 在设置中添加一个或多个扫描文件夹。
2. 配置每个文件夹的显示名称、分组、递归扫描、忽略规则和可选正则过滤。
3. 刷新全部文件夹，或从界面中刷新单个文件夹。
4. 在主项目列表中搜索、排序和分组项目。
5. 使用默认打开方式或每行指定的打开方式打开项目。
6. 从项目行或菜单栏项目菜单中运行脚本。

## 扫描配置

每个扫描文件夹支持：

- `displayName`：界面中显示的名称。
- `path`：要扫描的本地文件夹路径。
- `groupName`：自定义分组名称。
- `projectRegex`：可选的大小写不敏感正则，用于匹配项目名称和路径。
- `isEnabled`：保留配置但暂时不参与扫描。
- `recursiveScan`：启用后扫描嵌套目录。
- `detectGitWorktree`：面向该文件夹的 Worktree 检测开关。
- `ignorePods`：隐藏 Pods 生成的项目以及 `Pods` 路径下的项目。
- `ignoreExamples`：隐藏路径组件中包含 `example` 的目录。
- `ignoreCommonDirectories`：跳过常见生成目录和依赖目录。

常见跳过目录包括：

```text
DerivedData
Carthage
.build
node_modules
vendor
.git
```

递归扫描刻意不使用 `.skipsHiddenFiles`，因为 Git Worktree 经常放在 `.worktrees` 这类隐藏目录中。

## 项目识别

XcodeBar 在目录中发现以下任意信号时，会将该目录视为项目候选：

- `.xcworkspace`
- `.xcodeproj`
- `Package.swift`
- `Podfile`

同一根目录存在多个信号时，项目类型优先级为：

1. Workspace
2. Xcode Project
3. SwiftPM Package
4. Pods/Podfile Project

打开项目时的优先路径为 Workspace 路径，其次是 Xcode Project 路径，最后是项目根目录。

## Git 和 Worktree

XcodeBar 会从项目根目录读取 Git 元数据：

- 当前分支，或 detached HEAD 时的短提交哈希；
- Git 根路径；
- 是否处于 linked worktree；
- Worktree 名称；
- 可用时的主 Worktree 路径。

Worktree 会作为独立项目条目保留。打开项目和执行脚本时使用当前项目/Worktree 路径，而不是主仓库路径。

## 脚本

内置脚本包括：

- `pod install`
- `pod update`
- `swift package resolve`
- `git pull`
- `git status --short --branch`
- `xcodebuild clean`
- `open in Terminal`

脚本作用域包括：

- `Global`
- `Group`
- `Project`
- `Worktree`

项目和 Worktree 脚本会显示在项目行和项目菜单旁边。脚本可以要求执行前确认。执行结果会记录命令、工作目录、stdout、stderr、退出码和耗时。

## 菜单栏设置

菜单栏标题可以显示：

- 仅图标；
- 图标 + 当前项目；
- 图标 + 当前分支；
- 图标 + 当前 Worktree；
- 项目、分支和 Worktree 的自定义组合。

菜单区块可以独立开关，包括收藏项目、最近项目、当前分组、快速脚本、刷新控制、扫描状态和控制面板入口。设置中包含预览面板，方便在紧凑菜单栏显示前检查效果。

## 数据文件

设置文件位于：

```text
~/Library/Application Support/XcodeBar/settings.json
```

项目扫描缓存位于：

```text
~/Library/Application Support/XcodeBar/projects-cache.json
```

模型变更需要保持对旧 JSON 文件的向后兼容。

## 日志

扫描日志支持三个级别：

- `Info`
- `Warning`
- `Error`

默认 UI 过滤级别是 `Warning`。调试扫描行为时使用 `Info`，其中包含扫描选项、候选项目数量、正则过滤、过滤后数量和扫描耗时。

## 发布

创建并推送匹配 `v*` 的版本标签：

```bash
git tag v0.1.0
git push origin v0.1.0
```

`.github/workflows/release.yml` 会：

1. 以 release 模式构建 `XcodeBar`。
2. 将可执行文件包装为 `XcodeBar.app`。
3. 对应用进行 ad-hoc 签名。
4. 创建 DMG。
5. 将 DMG 上传到对应的 GitHub Release。

本地构建 DMG：

```bash
scripts/package-dmg.sh 0.1.0
```

## 仓库结构

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

## 开发说明

- 扫描逻辑保持在 `Sources/XcodeBar/Services/ProjectScanner.swift`。
- 持久化逻辑保持在 `Sources/XcodeBar/Services/PersistenceStore.swift`。
- 共享应用状态保持在 `Sources/XcodeBar/AppState.swift`。
- 模型默认值和自定义 `Codable` 初始化器需要保持向后兼容。
- 除非变更明确需要，不要清空用户设置或项目缓存。
- 当前没有专门的测试 Target；基础验证使用 `swift build`。

## License

XcodeBar 使用 MIT License 发布。详见 [LICENSE](LICENSE)。
