import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var isImportingFolder = false
    @State private var folderImportMode: FolderImportMode?
    @State private var selectedScriptID: UUID?
    @State private var editingScanFolderIDs: Set<UUID> = []

    var body: some View {
        TabView {
            scanFoldersTab
                .tabItem { Label("扫描", systemImage: "folder") }
            menuBarTab
                .tabItem { Label("菜单栏", systemImage: "menubar.rectangle") }
            scriptsTab
                .tabItem { Label("脚本", systemImage: "terminal") }
            logsTab
                .tabItem { Label("日志", systemImage: "list.bullet.rectangle") }
        }
        .padding()
        .fileImporter(isPresented: $isImportingFolder, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            let mode = folderImportMode
            folderImportMode = nil
            if case .success(let urls) = result, let url = urls.first {
                switch mode {
                case .add:
                    state.addScanFolder(url: url)
                case .authorize(let folderID):
                    state.authorizeScanFolder(id: folderID, url: url)
                case nil:
                    break
                }
                state.refreshAll()
            } else if case .failure(let error) = result {
                state.logs.append(ScanLogEntry(level: .error, message: "选择扫描文件夹失败：\(error.localizedDescription)"))
            }
        }
    }

    private var scanFoldersTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    beginFolderImport(.add)
                } label: {
                    Label("添加", systemImage: "folder.badge.plus")
                }
                .help("添加扫描文件夹")
                Button {
                    state.refreshAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("刷新全部")
                Spacer()
                Picker("默认打开方式", selection: $state.settings.defaultOpenTarget) {
                    ForEach(OpenTarget.allCases) { target in
                        Text(target.rawValue).tag(target)
                    }
                }
                .onChange(of: state.settings.defaultOpenTarget) { _ in state.saveSettings() }
            }

            List {
                ForEach($state.settings.scanFolders) { $folder in
                    let isEditing = editingScanFolderIDs.contains(folder.id)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("", isOn: $folder.isEnabled)
                                .labelsHidden()
                            TextField("显示名称", text: $folder.displayName)
                            TextField("分组名称", text: $folder.groupName)
                            Spacer()
                            Button {
                                state.refresh(folder: folder)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .help("刷新")
                            Button {
                                beginFolderImport(.authorize(folder.id))
                            } label: {
                                Image(systemName: folder.securityScopedBookmarkData == nil ? "lock.open" : "lock")
                            }
                            .help("重新授权扫描文件夹")
                            Button(role: .destructive) {
                                state.removeScanFolder(folder)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .help("删除")
                        }
                        Text(folder.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundStyle(.secondary)
                            TextField("项目名/路径正则（空值不过滤）", text: $folder.projectRegex)
                                .disabled(!isEditing)
                            Button {
                                if isEditing {
                                    editingScanFolderIDs.remove(folder.id)
                                    state.saveSettings()
                                } else {
                                    editingScanFolderIDs.insert(folder.id)
                                }
                            } label: {
                                Image(systemName: isEditing ? "checkmark.circle" : "pencil")
                            }
                            .help(isEditing ? "保存正则" : "修改正则")
                        }
                        HStack {
                            Toggle("递归扫描", isOn: $folder.recursiveScan)
                            Toggle("忽略 Pods", isOn: $folder.ignorePods)
                            Toggle("忽略 Example", isOn: $folder.ignoreExamples)
                            Toggle("忽略常见目录", isOn: $folder.ignoreCommonDirectories)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func beginFolderImport(_ mode: FolderImportMode) {
        folderImportMode = mode
        isImportingFolder = true
    }

    private var menuBarTab: some View {
        HStack(alignment: .top, spacing: 64) {
            VStack(alignment: .leading, spacing: 18) {
                settingsGroup("菜单栏") {
                    Toggle("显示 App 图标", isOn: menuBarToggle(\.showIcon))
                }

                settingsGroup("面板显示") {
                    Toggle("显示项目名", isOn: menuBarToggle(\.showCurrentProjectName))
                    Toggle("显示分支名", isOn: menuBarToggle(\.showCurrentBranchName))
                    Toggle("显示 Worktree 名称", isOn: menuBarToggle(\.showCurrentWorktreeName))
                }

                settingsGroup("下拉面板") {
                    Toggle("显示扫描状态", isOn: menuBarToggle(\.showScanStatus))
                    Toggle("显示收藏项目", isOn: menuBarToggle(\.showFavoritesSection))
                    Toggle("显示最近项目", isOn: menuBarToggle(\.showRecentSection))
                    Toggle("显示当前分组项目", isOn: menuBarToggle(\.showCurrentGroupSection))
                    Toggle("项目行显示脚本菜单", isOn: menuBarToggle(\.showQuickScriptsSection))
                    Toggle("显示刷新入口", isOn: menuBarToggle(\.showRefreshSection))
                    Toggle("显示控制面板入口", isOn: menuBarToggle(\.showControlPanelSection))
                }

                settingsGroup("刷新") {
                    HStack(spacing: 10) {
                        Text("自动刷新间隔")
                        Picker("", selection: Binding(
                            get: { state.settings.menuBar.autoRefreshInterval },
                            set: { newValue in
                                state.updateMenuBarSettings { $0.autoRefreshInterval = newValue }
                            }
                        )) {
                            Text("关闭").tag(TimeInterval(0))
                            Text("1 分钟").tag(TimeInterval(60))
                            Text("2 分钟").tag(TimeInterval(120))
                            Text("5 分钟").tag(TimeInterval(300))
                            Text("10 分钟").tag(TimeInterval(600))
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 150, alignment: .leading)
                    }
                }
            }
            .frame(width: 330, alignment: .leading)

            MenuBarPreviewView(settings: state.settings.menuBar, project: state.selectedProject, projectCount: state.projects.count)
                .frame(width: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 96)
    }

    private func settingsGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
        }
    }

    private func menuBarToggle(
        _ keyPath: WritableKeyPath<MenuBarSettings, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { state.settings.menuBar[keyPath: keyPath] },
            set: { newValue in
                state.updateMenuBarSettings { menuBar in
                    menuBar[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private var scriptsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("脚本操作")
                    .font(.headline)
                Spacer()
                Button {
                    let script = ScriptAction(name: "New Script", command: "", workingDirectory: nil, scope: .project)
                    state.settings.scripts.append(script)
                    selectedScriptID = script.id
                    state.saveSettings()
                } label: {
                    Label("添加", systemImage: "plus")
                }
                .help("添加脚本")
                Button {
                    state.settings.scripts = ScriptAction.presets
                    selectedScriptID = state.settings.scripts.first?.id
                    state.saveSettings()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .help("恢复预置")
            }

            HSplitView {
                List(selection: $selectedScriptID) {
                    ForEach(state.settings.scripts) { script in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(script.name.isEmpty ? "未命名脚本" : script.name)
                                .font(.body)
                            Text(script.scope.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(script.id)
                    }
                }
                .frame(minWidth: 210, idealWidth: 240)

                if let binding = selectedScriptBinding {
                    ScriptEditorView(script: binding) {
                        deleteSelectedScript()
                    }
                    .frame(minWidth: 420)
                } else {
                    ScriptEmptyStateView()
                        .frame(minWidth: 420)
                }
            }
            .onAppear {
                selectedScriptID = selectedScriptID ?? state.settings.scripts.first?.id
            }
            .onChange(of: state.settings.scripts) { _ in
                if let selectedScriptID, !state.settings.scripts.contains(where: { $0.id == selectedScriptID }) {
                    self.selectedScriptID = state.settings.scripts.first?.id
                }
                state.saveSettings()
            }
        }
    }

    private var selectedScriptBinding: Binding<ScriptAction>? {
        guard let selectedScriptID else { return nil }
        return Binding(
            get: {
                state.settings.scripts.first { $0.id == selectedScriptID } ?? ScriptAction(name: "", command: "", workingDirectory: nil, scope: .project)
            },
            set: { newValue in
                guard let index = state.settings.scripts.firstIndex(where: { $0.id == selectedScriptID }) else { return }
                state.settings.scripts[index] = newValue
            }
        )
    }

    private func deleteSelectedScript() {
        guard let selectedScriptID else { return }
        state.settings.scripts.removeAll { $0.id == selectedScriptID }
        self.selectedScriptID = state.settings.scripts.first?.id
        state.saveSettings()
    }

    private var logsTab: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("等级", selection: $state.settings.logLevel) {
                    ForEach(ScanLogEntry.Level.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .frame(width: 150)
                .onChange(of: state.settings.logLevel) { _ in state.saveSettings() }
                Button {
                    state.refreshAll()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("刷新全部")
                Button {
                    state.logs.removeAll()
                } label: {
                    Image(systemName: "trash")
                }
                .help("清空日志")
                Spacer()
            }
            Text(state.settings.logLevel == .info ? "Info 会显示扫描选项、候选项目数和过滤数量。" : "默认显示 Warning 和 Error。")
                .font(.caption)
                .foregroundStyle(.secondary)
            List(filteredLogs) { entry in
                HStack(alignment: .top) {
                    Text(entry.level.rawValue)
                        .font(.caption)
                        .frame(width: 64, alignment: .leading)
                        .foregroundStyle(logColor(for: entry.level))
                    Text(entry.date, style: .time)
                        .font(.caption)
                        .frame(width: 72, alignment: .leading)
                    Text(entry.message)
                }
            }
        }
    }

    private var filteredLogs: [ScanLogEntry] {
        state.logs.filter { entry in
            switch state.settings.logLevel {
            case .info:
                return true
            case .warning:
                return entry.level == .warning || entry.level == .error
            case .error:
                return entry.level == .error
            }
        }
    }

    private func logColor(for level: ScanLogEntry.Level) -> Color {
        switch level {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private enum FolderImportMode: Equatable {
    case add
    case authorize(ScanFolder.ID)
}

struct ScriptEditorView: View {
    @Binding var script: ScriptAction
    let onDelete: () -> Void

    var body: some View {
        Form {
            Section("基础信息") {
                TextField("名称", text: $script.name)
                Picker("Scope", selection: $script.scope) {
                    ForEach(ScriptScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                TextField("命令", text: $script.command, axis: .vertical)
                    .lineLimit(2...6)
                TextField("工作目录（留空使用当前项目/Worktree rootPath）", text: Binding(
                    get: { script.workingDirectory ?? "" },
                    set: { script.workingDirectory = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ))
            }

            Section("执行行为") {
                Toggle("执行前需要确认", isOn: $script.requiresConfirmation)
            }

            Section {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除脚本", systemImage: "trash")
                }
            }
        }
        .formStyle(.grouped)
        .padding(.leading, 12)
    }
}

struct ScriptEmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("选择一个脚本")
                .font(.headline)
            Text("从左侧选择脚本后编辑名称、命令、scope 和执行行为。")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct MenuBarPreviewView: View {
    let settings: MenuBarSettings
    let project: ProjectItem?
    let projectCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("预览")
                .font(.headline)

            HStack(spacing: 8) {
                if settings.showIcon {
                    Image(systemName: "hammer")
                } else {
                    Text("XcodeBar")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary, in: Capsule())

            VStack(alignment: .leading, spacing: 12) {
                previewHeader
                if settings.showScanStatus {
                    Label("\(projectCount) 个项目", systemImage: "tray.full")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                previewSection("收藏项目", isVisible: settings.showFavoritesSection)
                previewSection("最近项目", isVisible: settings.showRecentSection)
                previewSection("当前分组", isVisible: settings.showCurrentGroupSection)
                if settings.showQuickScriptsSection {
                    Label("项目行脚本菜单", systemImage: "terminal")
                        .font(.caption)
                }
                Divider()
                HStack {
                    if settings.showRefreshSection {
                        Image(systemName: "arrow.clockwise")
                    }
                    Spacer()
                    if settings.showControlPanelSection {
                        Image(systemName: "list.bullet.rectangle")
                        Image(systemName: "gearshape")
                    }
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            let parts = panelTitleParts
            if !parts.isEmpty {
                Text(parts.joined(separator: " / "))
                    .font(.headline)
            }
        }
    }

    private func previewSection(_ title: String, isVisible: Bool) -> some View {
        Group {
            if isVisible {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    previewProjectInfo
                }
            }
        }
    }

    private var previewProjectInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            if settings.showCurrentProjectName {
                Text(project?.name ?? "示例项目")
                    .font(.caption.weight(.semibold))
            }
            if settings.showCurrentBranchName {
                Label(project?.gitBranch ?? "-", systemImage: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if settings.showCurrentWorktreeName, let worktree = project?.worktreeName {
                Label(worktree, systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if panelTitleParts.isEmpty {
                Text("项目行")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var panelTitleParts: [String] {
        var parts: [String] = []
        if settings.showCurrentProjectName, let name = project?.name { parts.append(name) }
        if settings.showCurrentBranchName, let branch = project?.gitBranch { parts.append(branch) }
        if settings.showCurrentWorktreeName, let worktree = project?.worktreeName { parts.append(worktree) }
        return parts
    }
}
