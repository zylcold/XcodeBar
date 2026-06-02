import AppKit
import SwiftUI

struct MenuBarLabelView: View {
    let title: String
    let showIcon: Bool
    let isScanning: Bool

    var body: some View {
        if showIcon && !title.isEmpty {
            Label(title, systemImage: isScanning ? "arrow.triangle.2.circlepath" : "hammer")
        } else if showIcon {
            Image(systemName: isScanning ? "arrow.triangle.2.circlepath" : "hammer")
        } else {
            Text(title.isEmpty ? "XcodeBar" : title)
        }
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

            if state.settings.menuBar.showScanStatus {
                scanStatus
            }

            if state.settings.menuBar.showFavoritesSection {
                projectSection(title: "收藏项目", projects: favoriteProjects)
            }

            if state.settings.menuBar.showRecentSection {
                projectSection(title: "最近项目", projects: recentProjects)
            }

            if state.settings.menuBar.showCurrentGroupSection {
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
        .confirmationDialog(
            "执行脚本？",
            isPresented: Binding(
                get: { state.pendingScriptRequest != nil },
                set: { if !$0 { state.pendingScriptRequest = nil } }
            ),
            actions: {
                Button("执行") { state.confirmPendingScript() }
                Button("取消", role: .cancel) { state.pendingScriptRequest = nil }
            },
            message: {
                if let request = state.pendingScriptRequest {
                    Text("\(request.script.command)\n目录：\(request.workingDirectory)")
                }
            }
        )
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if state.isScanning {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                }
                Text(scanFolderNames)
                    .font(.headline)
            }
            if let lastRefresh = state.lastRefreshAt {
                Text("上次刷新：\(lastRefresh, style: .relative)前")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var scanFolderNames: String {
        let names = state.settings.scanFolders.filter(\.isEnabled).map(\.displayName)
        return names.isEmpty ? "XcodeBar" : names.joined(separator: " / ")
    }

    private var scanStatus: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: state.isScanning ? "arrow.triangle.2.circlepath" : "tray.full")
                Text(state.isScanning ? state.scanProgress.summary : "\(state.projects.count) 个项目")
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
        state.projects.filter { state.settings.favoriteProjectIDs.contains($0.id) }.prefix(5).map { $0 }
    }

    private var recentProjects: [ProjectItem] {
        state.projects
            .filter { $0.lastOpenedAt != nil }
            .sorted { ($0.lastOpenedAt ?? .distantPast) > ($1.lastOpenedAt ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    private var currentGroupProjects: [ProjectItem] {
        guard let group = state.selectedProject?.groupName else {
            return Array(state.projects.prefix(5))
        }
        return state.projects.filter { $0.groupName == group }.prefix(8).map { $0 }
    }

    private func projectSection(title: String, projects: [ProjectItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if projects.isEmpty {
                Text("暂无")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(projects) { project in
                    HStack(spacing: 8) {
                        Button {
                            state.open(project: project)
                        } label: {
                            Text(project.name)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text(project.gitBranch ?? "-")
                            .foregroundStyle(.secondary)
                            .font(.caption)

                        if let scheme = project.primarySchemeName {
                            Label(scheme, systemImage: "shippingbox")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if state.settings.menuBar.showQuickScriptsSection {
                            Menu {
                                ForEach(state.scripts(for: project)) { script in
                                    Button(script.name) {
                                        state.requestRun(script: script, project: project)
                                    }
                                }
                            } label: {
                                Image(systemName: "terminal")
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                            .help("脚本")
                        }
                    }
                }
            }
        }
    }
}
