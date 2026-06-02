import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published var projects: [ProjectItem] = []
    @Published var selectedProjectID: ProjectItem.ID?
    @Published var searchInput: String = ""
    @Published var searchText: String = ""
    @Published var sortMode: SortMode = .name
    @Published var groupMode: GroupMode = .folder
    @Published var collapsedGroups: Set<String> = []
    @Published var logs: [ScanLogEntry] = []
    @Published var isScanning: Bool = false
    @Published var scanProgress: ScanProgress = ScanProgress()
    @Published var lastScriptResult: ScriptResult?
    @Published var pendingScriptRequest: PendingScriptRequest?
    @Published var lastRefreshAt: Date?

    private let store = PersistenceStore()
    private let scanner = ProjectScanner()
    private let scriptRunner = ScriptRunner()
    private var cancellables: Set<AnyCancellable> = []
    private var lastMenuBarRefreshAt: Date = .distantPast
    private var autoRefreshTimer: Timer?

    init() {
        self.settings = store.loadSettings()
        self.projects = visibleProjects(from: store.loadProjectsCache())
        self.selectedProjectID = projects.first?.id
        $searchInput
            .removeDuplicates()
            .debounce(for: .milliseconds(220), scheduler: RunLoop.main)
            .sink { [weak self] value in
                self?.searchText = value
            }
            .store(in: &cancellables)
        startAutoRefreshTimer()
    }

    var selectedProject: ProjectItem? {
        projects.first { $0.id == selectedProjectID } ?? projects.first
    }

    var menuTitle: String {
        let project = selectedProject
        switch settings.menuBar.displayMode {
        case .iconOnly:
            return ""
        case .iconAndProject:
            return project?.name ?? "XcodeBar"
        case .iconAndBranch:
            return project?.gitBranch ?? "XcodeBar"
        case .iconAndWorktree:
            return project?.worktreeName ?? "XcodeBar"
        case .custom:
            var parts: [String] = []
            if settings.menuBar.showCurrentProjectName, let name = project?.name { parts.append(name) }
            if settings.menuBar.showCurrentBranchName, let branch = project?.gitBranch { parts.append(branch) }
            if settings.menuBar.showCurrentWorktreeName, let worktree = project?.worktreeName { parts.append(worktree) }
            return parts.isEmpty ? "XcodeBar" : parts.joined(separator: " / ")
        }
    }

    var filteredProjects: [ProjectItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let visible = visibleProjects(from: projects)
        let filtered = query.isEmpty ? visible : visible.filter { project in
            project.searchIndex.contains(query)
        }

        return filtered.sorted { lhs, rhs in
            switch sortMode {
            case .recent:
                return (lhs.lastOpenedAt ?? .distantPast) > (rhs.lastOpenedAt ?? .distantPast)
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .branch:
                return (lhs.gitBranch ?? "").localizedCaseInsensitiveCompare(rhs.gitBranch ?? "") == .orderedAscending
            case .group:
                return lhs.groupName.localizedCaseInsensitiveCompare(rhs.groupName) == .orderedAscending
            case .worktree:
                return (lhs.worktreeName ?? "").localizedCaseInsensitiveCompare(rhs.worktreeName ?? "") == .orderedAscending
            }
        }
    }

    var groupedProjects: [(name: String, projects: [ProjectItem])] {
        let grouped = Dictionary(grouping: filteredProjects) { project in
            switch groupMode {
            case .folder:
                return settings.scanFolders.first { $0.id == project.scanFolderID }?.displayName ?? project.groupName
            case .custom:
                return project.groupName
            case .worktree:
                return project.isWorktree ? (project.worktreeName ?? "Worktree") : "Main Repository"
            }
        }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    func saveSettings() {
        store.save(settings: settings)
        pruneHiddenCachedProjects()
    }

    func addScanFolder(path: String) {
        let name = URL(fileURLWithPath: path).lastPathComponent
        settings.scanFolders.append(ScanFolder(displayName: name.isEmpty ? "Projects" : name, path: path, groupName: name))
        saveSettings()
    }

    func removeScanFolder(_ folder: ScanFolder) {
        settings.scanFolders.removeAll { $0.id == folder.id }
        projects.removeAll { $0.scanFolderID == folder.id }
        saveSettings()
        store.saveProjectsCache(projects)
    }

    func refreshMenuBarIfNeeded() {
        let interval = settings.menuBar.autoRefreshInterval
        guard interval > 0 else { return }
        guard Date().timeIntervalSince(lastMenuBarRefreshAt) >= interval else { return }
        lastMenuBarRefreshAt = Date()
        refreshAll()
    }

    func restartAutoRefreshTimer() {
        startAutoRefreshTimer()
    }

    private func startAutoRefreshTimer() {
        autoRefreshTimer?.invalidate()
        let interval = settings.menuBar.autoRefreshInterval
        guard interval > 0 else { return }
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAll()
            }
        }
    }

    func refreshAll() {
        isScanning = true
        logs.removeAll()
        let folders = settings.scanFolders.filter(\.isEnabled)
        scanProgress = ScanProgress(totalFolders: folders.count, completedFolders: 0, currentFolderName: folders.first?.displayName, discoveredProjects: 0)
        if folders.isEmpty {
            logs = [ScanLogEntry(level: .warning, message: "没有启用的扫描文件夹")]
        }
        let totalStart = Date()
        Task.detached { [scanner] in
            var allProjects: [ProjectItem] = []
            var logEntries: [ScanLogEntry] = []
            for (index, folder) in folders.enumerated() {
                await MainActor.run {
                    self.scanProgress.currentFolderName = folder.displayName
                }
                let folderStart = Date()
                let scanned = scanner.scan(folder: folder) { level, message in
                    logEntries.append(ScanLogEntry(level: level, message: message))
                }
                let folderDuration = Date().timeIntervalSince(folderStart)
                logEntries.append(ScanLogEntry(level: .info, message: "扫描耗时：\(folder.displayName)，\(String(format: "%.2f", folderDuration))秒，发现 \(scanned.count) 个项目"))
                allProjects.append(contentsOf: scanned)
                let discoveredCount = allProjects.count
                await MainActor.run {
                    self.scanProgress.completedFolders = index + 1
                    self.scanProgress.discoveredProjects = discoveredCount
                }
            }
            let totalDuration = Date().timeIntervalSince(totalStart)
            logEntries.append(ScanLogEntry(level: .info, message: "全部扫描完成，总耗时 \(String(format: "%.2f", totalDuration))秒，共 \(allProjects.count) 个项目"))
            let finishedProjects = allProjects
            let finishedLogs = logEntries
            await MainActor.run {
                self.projects = self.visibleProjects(from: self.mergeLastOpened(scanned: finishedProjects))
                self.logs = finishedLogs
                self.isScanning = false
                self.lastRefreshAt = Date()
                self.scanProgress.currentFolderName = nil
                self.scanProgress.discoveredProjects = self.projects.count
                self.selectedProjectID = self.selectedProjectID ?? self.projects.first?.id
                self.store.saveProjectsCache(self.projects)
            }
        }
    }

    func refresh(folder: ScanFolder) {
        guard folder.isEnabled else {
            logs.append(ScanLogEntry(level: .warning, message: "扫描文件夹已禁用：\(folder.displayName)"))
            return
        }
        isScanning = true
        scanProgress = ScanProgress(totalFolders: 1, completedFolders: 0, currentFolderName: folder.displayName, discoveredProjects: projects.count)
        Task.detached { [scanner] in
            var logEntries: [ScanLogEntry] = []
            let folderStart = Date()
            let scanned = scanner.scan(folder: folder) { level, message in
                logEntries.append(ScanLogEntry(level: level, message: message))
            }
            let duration = Date().timeIntervalSince(folderStart)
            logEntries.append(ScanLogEntry(level: .info, message: "扫描耗时：\(folder.displayName)，\(String(format: "%.2f", duration))秒，发现 \(scanned.count) 个项目"))
            let finishedLogs = logEntries
            await MainActor.run {
                self.projects.removeAll { $0.scanFolderID == folder.id }
                self.projects.append(contentsOf: self.visibleProjects(from: self.mergeLastOpened(scanned: scanned)))
                self.projects.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.logs.append(contentsOf: finishedLogs)
                self.isScanning = false
                self.scanProgress = ScanProgress(totalFolders: 1, completedFolders: 1, currentFolderName: nil, discoveredProjects: self.projects.count)
                self.store.saveProjectsCache(self.projects)
            }
        }
    }

    func open(project: ProjectItem, target: OpenTarget? = nil) {
        ProjectOpener.open(project: project, target: target ?? settings.defaultOpenTarget)
        markOpened(project)
    }

    func run(script: ScriptAction, project: ProjectItem?) {
        Task.detached { [scriptRunner] in
            let result = scriptRunner.run(script: script, project: project)
            await MainActor.run {
                if script.showsExecutionWindow {
                    self.lastScriptResult = result
                }
            }
        }
    }

    func scripts(for project: ProjectItem?) -> [ScriptAction] {
        settings.scripts.filter { script in
            switch script.scope {
            case .global:
                return true
            case .group:
                return project != nil
            case .project:
                return project != nil
            case .worktree:
                return project?.isWorktree == true
            }
        }
    }

    func requestRun(script: ScriptAction, project: ProjectItem?) {
        if script.requiresConfirmation {
            pendingScriptRequest = PendingScriptRequest(script: script, project: project)
        } else {
            run(script: script, project: project)
        }
    }

    func confirmPendingScript() {
        guard let request = pendingScriptRequest else { return }
        pendingScriptRequest = nil
        run(script: request.script, project: request.project)
    }

    func toggleFavorite(project: ProjectItem) {
        if settings.favoriteProjectIDs.contains(project.id) {
            settings.favoriteProjectIDs.remove(project.id)
        } else {
            settings.favoriteProjectIDs.insert(project.id)
        }
        saveSettings()
    }

    private func markOpened(_ project: ProjectItem) {
        selectedProjectID = project.id
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].lastOpenedAt = Date()
            store.saveProjectsCache(projects)
        }
    }

    private func mergeLastOpened(scanned: [ProjectItem]) -> [ProjectItem] {
        scanned.map { item in
            var copy = item
            copy.lastOpenedAt = projects.first { $0.id == item.id }?.lastOpenedAt
            return copy
        }
    }

    private func pruneHiddenCachedProjects() {
        let visible = visibleProjects(from: projects)
        if visible != projects {
            projects = visible
            selectedProjectID = projects.first { $0.id == selectedProjectID }?.id ?? projects.first?.id
            store.saveProjectsCache(projects)
        }
    }

    private func visibleProjects(from source: [ProjectItem]) -> [ProjectItem] {
        source.filter { project in
            if ProjectScanner.isInternalXcodeProjectWorkspace(project) {
                return false
            }
            guard let folder = settings.scanFolders.first(where: { $0.id == project.scanFolderID }) else {
                return true
            }
            let podsVisible = !folder.ignorePods || !project.isPodsGeneratedProject
            let examplesVisible = !folder.ignoreExamples || !project.isExampleProject
            let regexVisible = projectMatchesFolderRegex(project: project, folder: folder)
            return podsVisible && examplesVisible && regexVisible
        }
    }

    private func projectMatchesFolderRegex(project: ProjectItem, folder: ScanFolder) -> Bool {
        let pattern = folder.projectRegex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty, let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return true
        }
        let text = project.searchIndex
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
