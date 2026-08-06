import Foundation

struct ScanFolder: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var displayName: String
    var path: String
    var groupName: String
    var securityScopedBookmarkData: Data?
    var projectRegex: String = ""
    var isEnabled: Bool = true
    var recursiveScan: Bool = true
    var detectGitWorktree: Bool = true
    var ignorePods: Bool = true
    var ignoreExamples: Bool = true
    var ignoreCommonDirectories: Bool = true

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case path
        case groupName
        case securityScopedBookmarkData
        case projectRegex
        case isEnabled
        case recursiveScan
        case detectGitWorktree
        case ignorePods
        case ignoreExamples
        case ignoreCommonDirectories
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        path: String,
        groupName: String,
        securityScopedBookmarkData: Data? = nil,
        projectRegex: String = "",
        isEnabled: Bool = true,
        recursiveScan: Bool = true,
        detectGitWorktree: Bool = true,
        ignorePods: Bool = true,
        ignoreExamples: Bool = true,
        ignoreCommonDirectories: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.groupName = groupName
        self.securityScopedBookmarkData = securityScopedBookmarkData
        self.projectRegex = projectRegex
        self.isEnabled = isEnabled
        self.recursiveScan = recursiveScan
        self.detectGitWorktree = detectGitWorktree
        self.ignorePods = ignorePods
        self.ignoreExamples = ignoreExamples
        self.ignoreCommonDirectories = ignoreCommonDirectories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        displayName = try container.decode(String.self, forKey: .displayName)
        path = try container.decode(String.self, forKey: .path)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName) ?? displayName
        securityScopedBookmarkData = try container.decodeIfPresent(Data.self, forKey: .securityScopedBookmarkData)
        projectRegex = try container.decodeIfPresent(String.self, forKey: .projectRegex) ?? ""
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        recursiveScan = try container.decodeIfPresent(Bool.self, forKey: .recursiveScan) ?? true
        detectGitWorktree = try container.decodeIfPresent(Bool.self, forKey: .detectGitWorktree) ?? true
        ignorePods = try container.decodeIfPresent(Bool.self, forKey: .ignorePods) ?? true
        ignoreExamples = try container.decodeIfPresent(Bool.self, forKey: .ignoreExamples) ?? true
        ignoreCommonDirectories = try container.decodeIfPresent(Bool.self, forKey: .ignoreCommonDirectories) ?? true
    }
}

enum ProjectType: String, Codable, CaseIterable, Hashable {
    case workspace = "Workspace"
    case xcodeproj = "XcodeProj"
    case swiftPM = "SwiftPM"
    case pods = "Pods"
}

enum OpenTarget: String, Codable, CaseIterable, Hashable, Identifiable {
    case xcode = "Xcode"
    case finder = "Finder"
    case terminal = "Terminal"
    case vscode = "VS Code"
    case cursor = "Cursor"

    var id: String { rawValue }
}

enum ScriptScope: String, Codable, CaseIterable, Hashable, Identifiable {
    case global = "Global"
    case group = "Group"
    case project = "Project"
    case worktree = "Worktree"

    var id: String { rawValue }
}

struct ScriptAction: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var command: String
    var workingDirectory: String?
    var scope: ScriptScope
    var requiresConfirmation: Bool = true
    var showsExecutionWindow: Bool = true
    /// 是否在下拉面板项目行显示为快捷图标
    var showInMenuBar: Bool = false
    /// 快捷图标 emoji；为空时回退到默认 terminal SF Symbol
    var emojiIcon: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case command
        case workingDirectory
        case scope
        case requiresConfirmation
        case showsExecutionWindow
        case showInMenuBar
        case emojiIcon
    }

    init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String?,
        scope: ScriptScope,
        requiresConfirmation: Bool = true,
        showsExecutionWindow: Bool = true,
        showInMenuBar: Bool = false,
        emojiIcon: String = ""
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.scope = scope
        self.requiresConfirmation = requiresConfirmation
        self.showsExecutionWindow = showsExecutionWindow
        self.showInMenuBar = showInMenuBar
        self.emojiIcon = emojiIcon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        command = try container.decode(String.self, forKey: .command)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        scope = try container.decode(ScriptScope.self, forKey: .scope)
        requiresConfirmation = try container.decodeIfPresent(Bool.self, forKey: .requiresConfirmation) ?? true
        showsExecutionWindow = try container.decodeIfPresent(Bool.self, forKey: .showsExecutionWindow) ?? true
        showInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? false
        emojiIcon = try container.decodeIfPresent(String.self, forKey: .emojiIcon) ?? ""
    }
}

struct ProjectItem: Identifiable, Codable, Hashable {
    var id: String { rootPath + "|" + (workspacePath ?? xcodeprojPath ?? packagePath ?? podfilePath ?? "") }
    var name: String
    var rootPath: String
    var groupName: String
    var scanFolderID: UUID
    var projectType: ProjectType
    var workspacePath: String?
    var xcodeprojPath: String?
    var packagePath: String?
    var podfilePath: String?
    var hasPods: Bool
    var hasXcodeGen: Bool
    var schemes: [String] = []
    var gitBranch: String?
    var gitRootPath: String?
    var isWorktree: Bool
    var worktreeName: String?
    var worktreeMainPath: String?
    var lastOpenedAt: Date?

    enum CodingKeys: String, CodingKey {
        case name
        case rootPath
        case groupName
        case scanFolderID
        case projectType
        case workspacePath
        case xcodeprojPath
        case packagePath
        case podfilePath
        case hasPods
        case hasXcodeGen
        case schemes
        case gitBranch
        case gitRootPath
        case isWorktree
        case worktreeName
        case worktreeMainPath
        case lastOpenedAt
    }

    init(
        name: String,
        rootPath: String,
        groupName: String,
        scanFolderID: UUID,
        projectType: ProjectType,
        workspacePath: String?,
        xcodeprojPath: String?,
        packagePath: String?,
        podfilePath: String?,
        hasPods: Bool,
        hasXcodeGen: Bool = false,
        schemes: [String] = [],
        gitBranch: String?,
        gitRootPath: String?,
        isWorktree: Bool,
        worktreeName: String?,
        worktreeMainPath: String?,
        lastOpenedAt: Date?
    ) {
        self.name = name
        self.rootPath = rootPath
        self.groupName = groupName
        self.scanFolderID = scanFolderID
        self.projectType = projectType
        self.workspacePath = workspacePath
        self.xcodeprojPath = xcodeprojPath
        self.packagePath = packagePath
        self.podfilePath = podfilePath
        self.hasPods = hasPods
        self.hasXcodeGen = hasXcodeGen
        self.schemes = schemes
        self.gitBranch = gitBranch
        self.gitRootPath = gitRootPath
        self.isWorktree = isWorktree
        self.worktreeName = worktreeName
        self.worktreeMainPath = worktreeMainPath
        self.lastOpenedAt = lastOpenedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        rootPath = try container.decode(String.self, forKey: .rootPath)
        groupName = try container.decode(String.self, forKey: .groupName)
        scanFolderID = try container.decode(UUID.self, forKey: .scanFolderID)
        projectType = try container.decode(ProjectType.self, forKey: .projectType)
        workspacePath = try container.decodeIfPresent(String.self, forKey: .workspacePath)
        xcodeprojPath = try container.decodeIfPresent(String.self, forKey: .xcodeprojPath)
        packagePath = try container.decodeIfPresent(String.self, forKey: .packagePath)
        podfilePath = try container.decodeIfPresent(String.self, forKey: .podfilePath)
        hasPods = try container.decodeIfPresent(Bool.self, forKey: .hasPods) ?? false
        hasXcodeGen = try container.decodeIfPresent(Bool.self, forKey: .hasXcodeGen) ?? false
        schemes = try container.decodeIfPresent([String].self, forKey: .schemes) ?? []
        gitBranch = try container.decodeIfPresent(String.self, forKey: .gitBranch)
        gitRootPath = try container.decodeIfPresent(String.self, forKey: .gitRootPath)
        isWorktree = try container.decodeIfPresent(Bool.self, forKey: .isWorktree) ?? false
        worktreeName = try container.decodeIfPresent(String.self, forKey: .worktreeName)
        worktreeMainPath = try container.decodeIfPresent(String.self, forKey: .worktreeMainPath)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt)
    }

    var preferredOpenPath: String {
        workspacePath ?? xcodeprojPath ?? rootPath
    }

    var isPodsGeneratedProject: Bool {
        let lowerName = name.lowercased()
        if lowerName == "pods" || lowerName == "_pods" || lowerName.hasPrefix("pods-") || lowerName.hasPrefix("_pods-") {
            return true
        }
        let paths = [rootPath, workspacePath, xcodeprojPath, packagePath, podfilePath].compactMap { $0 }
        return paths.contains { path in
            path.split(separator: "/").contains { $0 == "Pods" }
        }
    }

    var primarySchemeName: String? {
        schemes.first
    }

    /// 优先使用 Git 分支名；沙盒/无 Git 信息时回退到 worktree 名；
    /// 再回退到从 rootPath 推断的 `.worktree(s)/xxx` 目录名。
    var branchOrWorktreeName: String? {
        if let gitBranch, !gitBranch.isEmpty { return gitBranch }
        return effectiveWorktreeName
    }

    /// 实际可用的 worktree 名：已识别的 worktreeName 优先，
    /// 否则从 rootPath 推断 `.worktree` / `.worktrees` 目录下的子目录名。
    var effectiveWorktreeName: String? {
        if let worktreeName, !worktreeName.isEmpty { return worktreeName }
        let components = rootPath.split(separator: "/").map(String.init)
        for (index, component) in components.enumerated() {
            let lower = component.lowercased()
            if (lower == ".worktree" || lower == ".worktrees"),
               index + 1 < components.count,
               !components[index + 1].isEmpty {
                return components[index + 1]
            }
        }
        return nil
    }

    var searchIndex: String {
        [
            name,
            rootPath,
            gitBranch,
            groupName,
            worktreeName,
            primarySchemeName,
            schemes.joined(separator: " "),
            hasXcodeGen ? "xcodegen" : nil
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }

    var nameAndPathSearchText: String {
        [
            name,
            rootPath,
            workspacePath,
            xcodeprojPath,
            packagePath,
            podfilePath
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()
    }

    var isExampleProject: Bool {
        let paths = [rootPath, workspacePath, xcodeprojPath, packagePath, podfilePath].compactMap { $0 }
        return paths.contains { path in
            path.split(separator: "/").contains { component in
                component.lowercased().contains("example")
            }
        }
    }
}

struct ScanProgress: Hashable {
    var totalFolders: Int = 0
    var completedFolders: Int = 0
    var currentFolderName: String?
    var discoveredProjects: Int = 0

    var fraction: Double {
        guard totalFolders > 0 else { return 0 }
        return min(Double(completedFolders) / Double(totalFolders), 1)
    }

    var summary: String {
        if totalFolders == 0 {
            return "等待扫描"
        }
        let current = currentFolderName.map { " · \($0)" } ?? ""
        return "\(completedFolders)/\(totalFolders) · \(discoveredProjects) 个项目\(current)"
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case recent = "最近打开"
    case name = "名称"
    case branch = "分支"
    case group = "分组"
    case worktree = "Worktree"

    var id: String { rawValue }
}

enum GroupMode: String, CaseIterable, Identifiable {
    case folder = "扫描文件夹"
    case custom = "自定义分组"
    case worktree = "Git Worktree"

    var id: String { rawValue }
}

struct MenuBarSettings: Codable, Hashable {
    enum DisplayMode: String, Codable, CaseIterable, Identifiable {
        case iconOnly = "仅图标"
        case iconAndProject = "图标 + 当前项目"
        case iconAndBranch = "图标 + 当前分支"
        case iconAndWorktree = "图标 + 当前 Worktree"
        case custom = "自定义组合"

        var id: String { rawValue }
    }

    var showIcon: Bool = true
    var showCurrentProjectName: Bool = true
    var showCurrentBranchName: Bool = true
    var showCurrentWorktreeName: Bool = false
    var showRecentProjects: Bool = true
    var showFavoriteProjects: Bool = true
    var showQuickScripts: Bool = true
    var showScanStatus: Bool = true
    var displayMode: DisplayMode = .iconAndProject
    var showFavoritesSection: Bool = true
    var showRecentSection: Bool = true
    var showCurrentGroupSection: Bool = true
    var showQuickScriptsSection: Bool = true
    var showRefreshSection: Bool = true
    var showControlPanelSection: Bool = true
    var autoRefreshInterval: TimeInterval = 120
}

struct AppSettings: Codable, Hashable {
    var scanFolders: [ScanFolder] = []
    var defaultOpenTarget: OpenTarget = .xcode
    var scripts: [ScriptAction] = ScriptAction.presets
    var menuBar: MenuBarSettings = MenuBarSettings()
    var favoriteProjectIDs: Set<String> = []
    var logLevel: ScanLogEntry.Level = .warning
}

struct ScanLogEntry: Identifiable, Hashable {
    enum Level: String, CaseIterable, Identifiable, Codable {
        case info = "Info"
        case warning = "Warning"
        case error = "Error"

        var id: String { rawValue }
    }

    var id = UUID()
    var date = Date()
    var level: Level
    var message: String
}

struct ScriptResult: Identifiable, Hashable {
    var id = UUID()
    var scriptName: String
    var command: String
    var workingDirectory: String
    var stdout: String
    var stderr: String
    var exitCode: Int32
    var duration: TimeInterval
}

struct PendingScriptRequest: Identifiable, Hashable {
    var id = UUID()
    var script: ScriptAction
    var project: ProjectItem?

    var workingDirectory: String {
        script.workingDirectory?.isEmpty == false ? script.workingDirectory! : (project?.rootPath ?? FileManager.default.homeDirectoryForCurrentUser.path)
    }
}

extension ScriptAction {
    static let presets: [ScriptAction] = [
        ScriptAction(name: "pod install", command: "pod install", workingDirectory: nil, scope: .project),
        ScriptAction(name: "pod update", command: "pod update", workingDirectory: nil, scope: .project),
        ScriptAction(name: "swift package resolve", command: "swift package resolve", workingDirectory: nil, scope: .project),
        ScriptAction(name: "git pull", command: "git pull", workingDirectory: nil, scope: .project),
        ScriptAction(name: "git status", command: "git status --short --branch", workingDirectory: nil, scope: .project),
        ScriptAction(name: "xcodebuild clean", command: "xcodebuild clean", workingDirectory: nil, scope: .project),
        ScriptAction(name: "open in Terminal", command: "open -a Terminal .", workingDirectory: nil, scope: .project, requiresConfirmation: false)
    ]
}
