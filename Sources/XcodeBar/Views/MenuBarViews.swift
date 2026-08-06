import AppKit
import SwiftUI

struct MenuBarLabelView: View {
    let isScanning: Bool

    var body: some View {
        Image(systemName: isScanning ? "arrow.triangle.2.circlepath" : "hammer")
    }
}

struct MenuBarContentView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
                .task {
                    state.refreshMenuBarIfNeeded()
                }

            if state.enabledScanFolders.count > 1 {
                folderSwitcher
            }

            if state.settings.menuBar.showScanStatus {
                scanStatus
            }

            if state.settings.menuBar.showFavoritesSection {
                projectSection(title: "收藏项目", projects: favoriteProjects)
            }

            if state.settings.menuBar.showRecentSection {
                projectSection(title: "最近项目", projects: recentProjects)
            }

            if state.selectedMenuScanFolder != nil, state.settings.menuBar.showCurrentGroupSection {
                projectSection(title: "当前分组", projects: currentGroupProjects)
            }

            Divider()
            HStack {
                if state.settings.menuBar.showRefreshSection {
                    Button {
                        state.refreshAll()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("刷新")
                }
                Spacer()
                if state.settings.menuBar.showControlPanelSection {
                    Button {
                        openSingletonWindow(id: "main", title: "XcodeBar")
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .help("项目列表")
                    Button {
                        openSingletonWindow(id: "settings", title: "设置")
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .help("设置")
                }
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("退出 XcodeBar")
            }
        }
        .padding(14)
    }

    private func openSingletonWindow(id: String, title: String) {
        NSApp.setActivationPolicy(.regular)
        NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
        openWindow(id: id)
        scheduleFocus(title: title)
        observeWindowClose()
    }

    private func scheduleFocus(title: String) {
        var attempts = 0
        let maxAttempts = 10
        func tryFocus() {
            attempts += 1
            guard let window = NSApp.windows.first(where: { $0.title == title }) else {
                if attempts < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: tryFocus)
                }
                return
            }
            NSRunningApplication.current.activate(options: .activateIgnoringOtherApps)
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: tryFocus)
    }

    private func observeWindowClose() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let visibleWindows = NSApp.windows.filter {
                    $0.isVisible && $0.title != "" && $0.className.contains("SwiftUI")
                }
                if visibleWindows.isEmpty {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if state.isScanning {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
            }
            Text(selectedFolderName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if let lastRefresh = state.lastRefreshAt {
                Text("上次刷新：\(lastRefresh, style: .relative)前")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var selectedFolderName: String {
        state.selectedMenuScanFolder?.displayName ?? "Overview"
    }

    private var folderSwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                folderSwitcherButton(
                    title: "Overview",
                    systemImage: "square.grid.2x2",
                    count: state.projects.count,
                    isSelected: state.selectedMenuScanFolderID == nil
                ) {
                    state.selectedMenuScanFolderID = nil
                }

                ForEach(state.enabledScanFolders) { folder in
                    folderSwitcherButton(
                        title: folder.displayName,
                        systemImage: "folder",
                        count: projectCount(in: folder),
                        isSelected: folder.id == state.selectedMenuScanFolderID
                    ) {
                        state.selectedMenuScanFolderID = folder.id
                    }
                    .help(folder.path)
                }
            }
        }
    }

    private func folderSwitcherButton(
        title: String,
        systemImage: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
            }
        }
        .buttonStyle(.plain)
    }

    private func projectCount(in folder: ScanFolder) -> Int {
        state.projects.filter { $0.scanFolderID == folder.id }.count
    }

    private var scanStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: state.isScanning ? "arrow.triangle.2.circlepath" : "tray.full")
                Text(state.isScanning ? state.scanProgress.summary : "\(state.menuScopedProjects.count) 个项目")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if state.isScanning {
                ProgressView(value: state.scanProgress.fraction)
                    .controlSize(.small)
            }
        }
    }

    private var favoriteProjects: [ProjectItem] {
        state.menuScopedProjects.filter { state.settings.favoriteProjectIDs.contains($0.id) }.prefix(5).map { $0 }
    }

    private var recentProjects: [ProjectItem] {
        state.menuScopedProjects
            .filter { $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    private var currentGroupProjects: [ProjectItem] {
        guard let group = state.selectedProject?.groupName else {
            return Array(state.menuScopedProjects.prefix(8))
        }
        let grouped = state.menuScopedProjects.filter { $0.groupName == group }
        return (grouped.isEmpty ? state.menuScopedProjects : grouped).prefix(8).map { $0 }
    }

    private func projectSection(title: String, projects: [ProjectItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if projects.isEmpty {
                Text("暂无")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(projects) { project in
                    projectRow(project)
                }
            }
        }
    }

    private func projectRow(_ project: ProjectItem) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                state.open(project: project)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    if state.settings.menuBar.showCurrentProjectName {
                        Text(project.name)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                    }
                    if state.settings.menuBar.showCurrentBranchName,
                       let branch = project.branchOrWorktreeName {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.branch")
                                .foregroundStyle(.secondary)
                            MarqueeText(text: branch, width: 100)
                        }
                        .font(.caption)
                    }
                    if state.settings.menuBar.showCurrentWorktreeName, let worktree = project.effectiveWorktreeName {
                        Label(worktree, systemImage: "point.3.connected.trianglepath.dotted")
                            .lineLimit(1)
                            .help(worktree)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !state.settings.menuBar.showCurrentProjectName,
                       !state.settings.menuBar.showCurrentBranchName,
                       !state.settings.menuBar.showCurrentWorktreeName {
                        Text(project.name)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ForEach(state.quickMenuScripts(for: project)) { script in
                Button {
                    state.requestRun(script: script, project: project)
                } label: {
                    Group {
                        if script.emojiIcon.isEmpty {
                            Image(systemName: "terminal")
                        } else {
                            Text(script.emojiIcon)
                        }
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle().fill(Color.primary.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .help("\(script.name)（\(script.command)）")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

/// 固定宽度的文本，内容超出时自动跑马灯滚动；未超出时居左静态展示。
struct MarqueeText: View {
    let text: String
    let width: CGFloat
    var font: Font = .caption
    var color: Color = .secondary

    @State private var contentWidth: CGFloat = 0
    @State private var phase: CGFloat = 0
    @State private var isAnimating = false

    /// 滚动速度（pt/秒）
    private static var speed: Double { 28 }
    /// 文本与下一轮副本之间的间距
    private static var gap: CGFloat { 28 }

    private var needsMarquee: Bool {
        contentWidth > width
    }

    private var scrollDistance: CGFloat {
        contentWidth + Self.gap
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if needsMarquee {
                HStack(spacing: Self.gap) {
                    Text(text)
                    Text(text)
                }
                .font(font)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
                .offset(x: phase)
            } else {
                Text(text)
                    .font(font)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
        .frame(width: width, alignment: .leading)
        .clipped()
        .background(
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .hidden()
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: MarqueeWidthKey.self, value: proxy.size.width)
                })
        )
        .onPreferenceChange(MarqueeWidthKey.self) { value in
            contentWidth = value
            guard value > width, !isAnimating else { return }
            isAnimating = true
            phase = 0
            let duration = max(Double(scrollDistance) / Self.speed, 1.0)
            DispatchQueue.main.async {
                withAnimation(.linear(duration: duration)
                    .repeatForever(autoreverses: false)) {
                    phase = -scrollDistance
                }
            }
        }
        .id(text)
    }
}

private struct MarqueeWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
