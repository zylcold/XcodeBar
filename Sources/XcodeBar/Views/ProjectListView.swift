import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            content
        }
    }

    private var sidebar: some View {
        List(selection: $state.selectedProjectID) {
            Section("扫描文件夹") {
                ForEach(state.settings.scanFolders) { folder in
                    HStack {
                        Circle()
                            .fill(folder.isEnabled ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(folder.displayName)
                        Spacer()
                        Button {
                            state.refresh(folder: folder)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("XcodeBar")
        .toolbar {
            Button {
                state.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            toolbar
            if state.isScanning {
                scanProgressBar
            }
            Divider()
            ScrollView {
                LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                    ForEach(state.groupedProjects, id: \.name) { group in
                        Section {
                            if !state.collapsedGroups.contains(group.name) {
                                ForEach(group.projects) { project in
                                    ProjectRowView(project: project)
                                        .environmentObject(state)
                                        .padding(.horizontal)
                                }
                            }
                        } header: {
                            GroupHeaderView(name: group.name, count: group.projects.count)
                                .environmentObject(state)
                        }
                    }
                }
                .padding(.vertical)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索", text: $state.searchInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 360)

            Picker("分组", selection: $state.groupMode) {
                ForEach(GroupMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .frame(width: 150)

            Picker("排序", selection: $state.sortMode) {
                ForEach(SortMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .frame(width: 130)

            Spacer()

            Button {
                state.refreshAll()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("刷新全部")
            .disabled(state.isScanning)
        }
        .padding()
    }

    private var scanProgressBar: some View {
        HStack(spacing: 10) {
            ProgressView(value: state.scanProgress.fraction)
                .frame(width: 180)
            Text(state.scanProgress.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct GroupHeaderView: View {
    @EnvironmentObject private var state: AppState
    let name: String
    let count: Int

    var body: some View {
        HStack {
            Button {
                toggle()
            } label: {
                Image(systemName: state.collapsedGroups.contains(name) ? "chevron.right" : "chevron.down")
            }
            .buttonStyle(.plain)

            Text(name)
                .font(.headline)
            Text("\(count)")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
            Spacer()
            Button {
                refreshGroup()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("刷新分组")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.background)
    }

    private func toggle() {
        if state.collapsedGroups.contains(name) {
            state.collapsedGroups.remove(name)
        } else {
            state.collapsedGroups.insert(name)
        }
    }

    private func refreshGroup() {
        let folders = state.settings.scanFolders.filter { folder in
            folder.displayName == name || folder.groupName == name
        }
        if folders.isEmpty {
            state.refreshAll()
        } else {
            folders.forEach { state.refresh(folder: $0) }
        }
    }
}

struct ProjectRowView: View {
    @EnvironmentObject private var state: AppState
    let project: ProjectItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(project.name)
                        .font(.headline)
                    Text(project.projectType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                    if project.hasPods {
                        Text("Pods")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.18), in: Capsule())
                    }
                    if project.hasXcodeGen {
                        Text("XcodeGen")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.purple.opacity(0.16), in: Capsule())
                    }
                    if project.isWorktree {
                        Text(project.effectiveWorktreeName ?? "Worktree")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.16), in: Capsule())
                    }
                }
                HStack(spacing: 12) {
                    Label(project.branchOrWorktreeName ?? "-", systemImage: "arrow.triangle.branch")
                    Label(project.primarySchemeName ?? "-", systemImage: "shippingbox")
                    Label(project.groupName, systemImage: "folder")
                    Text(project.rootPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                state.toggleFavorite(project: project)
            } label: {
                Image(systemName: state.settings.favoriteProjectIDs.contains(project.id) ? "star.fill" : "star")
            }
            .help("收藏")
            Button {
                state.open(project: project)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .help("打开")
            Menu {
                ForEach(OpenTarget.allCases) { target in
                    Button {
                        state.open(project: project, target: target)
                    } label: {
                        Label(target.rawValue, systemImage: target.systemImage)
                    }
                }
                Divider()
                ForEach(state.scripts(for: project)) { script in
                    Button {
                        state.requestRun(script: script, project: project)
                    } label: {
                        Label(script.name, systemImage: "terminal")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .help("更多")
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension OpenTarget {
    var systemImage: String {
        switch self {
        case .xcode: return "hammer"
        case .finder: return "folder"
        case .terminal: return "terminal"
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow"
        }
    }
}

struct ScriptResultView: View {
    let result: ScriptResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.scriptName)
                .font(.title2)
            Text("目录：\(result.workingDirectory)")
            Text("退出码：\(result.exitCode)  耗时：\(String(format: "%.2fs", result.duration))")
            Divider()
            Text("stdout")
                .font(.headline)
            ScrollView {
                Text(result.stdout.isEmpty ? "(empty)" : result.stdout)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("stderr")
                .font(.headline)
            ScrollView {
                Text(result.stderr.isEmpty ? "(empty)" : result.stderr)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .frame(width: 720, height: 520)
    }
}
