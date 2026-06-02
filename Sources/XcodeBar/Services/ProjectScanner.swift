import Foundation

struct ProjectScanner {
    private let ignoredDirectories: Set<String> = ["DerivedData", "Carthage", ".build", "node_modules", "vendor", ".git"]

    func scan(folder: ScanFolder, log: (ScanLogEntry.Level, String) -> Void) -> [ProjectItem] {
        guard folder.isEnabled else { return [] }
        let rootURL = URL(fileURLWithPath: folder.path).standardizedFileURL
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            log(.error, "扫描文件夹不存在：\(folder.path)")
            return []
        }

        log(.info, "开始扫描：\(folder.displayName) \(rootURL.path)")
        log(.info, "扫描选项：递归=\(folder.recursiveScan)，忽略 Pods=\(folder.ignorePods)，忽略 Example=\(folder.ignoreExamples)，忽略常见目录=\(folder.ignoreCommonDirectories)，正则=\(folder.projectRegex.isEmpty ? "空" : folder.projectRegex)")
        var candidates: [String: ProjectCandidate] = [:]
        scanDirectory(rootURL, folder: folder, candidates: &candidates, log: log)
        let regex = projectRegex(for: folder, log: log)

        let scannedProjects = candidates.values.map { candidate in
            makeProject(from: candidate, folder: folder)
        }
        log(.info, "候选项目：\(folder.displayName)，\(scannedProjects.count) 个")

        let projects = scannedProjects
            .filter { !folder.ignorePods || !$0.isPodsGeneratedProject }
            .filter { !folder.ignoreExamples || !$0.isExampleProject }
            .filter { matches(project: $0, regex: regex) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let filteredCount = scannedProjects.count - projects.count
        if filteredCount > 0 {
            log(.info, "过滤项目：\(folder.displayName)，隐藏 \(filteredCount) 个")
        }
        if projects.isEmpty {
            log(.warning, "未发现可显示项目：\(folder.displayName)")
        }
        log(.info, "扫描完成：\(folder.displayName)，发现 \(projects.count) 个项目")
        return projects
    }

    private func scanDirectory(
        _ rootURL: URL,
        folder: ScanFolder,
        candidates: inout [String: ProjectCandidate],
        log: (ScanLogEntry.Level, String) -> Void
    ) {
        if folder.recursiveScan {
            guard let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            ) else { return }

            for case let url as URL in enumerator {
                if isProjectContainer(url) {
                    inspect(url: url, folder: folder, candidates: &candidates)
                    enumerator.skipDescendants()
                    continue
                }
                if shouldSkip(url: url, folder: folder) {
                    enumerator.skipDescendants()
                    continue
                }
                inspect(url: url, folder: folder, candidates: &candidates)
            }
        } else {
            do {
                let urls = try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey])
                urls.forEach { inspect(url: $0, folder: folder, candidates: &candidates) }
            } catch {
                log(.error, "读取目录失败：\(rootURL.path) \(error.localizedDescription)")
            }
        }
    }

    private func shouldSkip(url: URL, folder: ScanFolder) -> Bool {
        if folder.ignorePods && url.lastPathComponent == "Pods" {
            return true
        }
        if folder.ignoreExamples && url.lastPathComponent.lowercased().contains("example") {
            return true
        }
        guard folder.ignoreCommonDirectories else {
            return false
        }
        return ignoredDirectories.contains(url.lastPathComponent)
    }

    private func isProjectContainer(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        return pathExtension == "xcodeproj" || pathExtension == "xcworkspace"
    }

    private func inspect(url: URL, folder: ScanFolder, candidates: inout [String: ProjectCandidate]) {
        let pathExtension = url.pathExtension.lowercased()
        let name = url.lastPathComponent
        let parent = url.deletingLastPathComponent().standardizedFileURL.path
        var candidate = candidates[parent] ?? ProjectCandidate(rootPath: parent)

        if pathExtension == "xcworkspace" {
            candidate.workspacePath = url.path
        } else if pathExtension == "xcodeproj" {
            if !folder.ignorePods || !isPodsGeneratedPath(url.path) {
                candidate.xcodeprojPath = url.path
            }
        } else if name == "Package.swift" {
            candidate.packagePath = url.path
        } else if name == "Podfile" {
            candidate.podfilePath = url.path
        }

        if candidate.hasProjectSignal {
            candidates[parent] = candidate
        }
    }

    private func makeProject(from candidate: ProjectCandidate, folder: ScanFolder) -> ProjectItem {
        let rootPath = candidate.rootPath
        let gitInfo = gitMetadata(at: rootPath, detectWorktree: true)
        let type: ProjectType
        if candidate.workspacePath != nil {
            type = .workspace
        } else if candidate.xcodeprojPath != nil {
            type = .xcodeproj
        } else if candidate.packagePath != nil {
            type = .swiftPM
        } else {
            type = .pods
        }

        return ProjectItem(
            name: projectName(candidate: candidate),
            rootPath: rootPath,
            groupName: folder.groupName.isEmpty ? folder.displayName : folder.groupName,
            scanFolderID: folder.id,
            projectType: type,
            workspacePath: candidate.workspacePath,
            xcodeprojPath: candidate.xcodeprojPath,
            packagePath: candidate.packagePath,
            podfilePath: candidate.podfilePath,
            hasPods: candidate.podfilePath != nil,
            schemes: schemeNames(for: candidate),
            gitBranch: gitInfo.branch,
            gitRootPath: gitInfo.root,
            isWorktree: gitInfo.isWorktree,
            worktreeName: gitInfo.worktreeName,
            worktreeMainPath: gitInfo.mainPath,
            lastOpenedAt: nil
        )
    }

    private func projectName(candidate: ProjectCandidate) -> String {
        if let workspace = candidate.workspacePath {
            return URL(fileURLWithPath: workspace).deletingPathExtension().lastPathComponent
        }
        if let xcodeproj = candidate.xcodeprojPath {
            return URL(fileURLWithPath: xcodeproj).deletingPathExtension().lastPathComponent
        }
        return URL(fileURLWithPath: candidate.rootPath).lastPathComponent
    }

    private func isPodsGeneratedPath(_ path: String) -> Bool {
        let components = path.split(separator: "/")
        if components.contains(where: { $0 == "Pods" }) {
            return true
        }
        let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent.lowercased()
        return name == "pods" || name == "_pods" || name.hasPrefix("pods-") || name.hasPrefix("_pods-")
    }

    private func projectRegex(for folder: ScanFolder, log: (ScanLogEntry.Level, String) -> Void) -> NSRegularExpression? {
        let pattern = folder.projectRegex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return nil }
        do {
            return try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            log(.error, "正则无效：\(folder.displayName) \(error.localizedDescription)")
            return nil
        }
    }

    private func matches(project: ProjectItem, regex: NSRegularExpression?) -> Bool {
        guard let regex else { return true }
        let text = project.searchIndex
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }

    static func isInternalXcodeProjectWorkspace(_ project: ProjectItem) -> Bool {
        guard project.name == "project", let workspacePath = project.workspacePath else {
            return false
        }
        return workspacePath.split(separator: "/").contains { $0.hasSuffix(".xcodeproj") }
    }

    private func schemeNames(for candidate: ProjectCandidate) -> [String] {
        let containers = [candidate.workspacePath, candidate.xcodeprojPath].compactMap { $0 }
        var names: [String] = []
        for container in containers {
            names.append(contentsOf: schemeNames(in: URL(fileURLWithPath: container)))
        }
        return Array(Set(names)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func schemeNames(in containerURL: URL) -> [String] {
        let sharedSchemes = containerURL.appendingPathComponent("xcshareddata/xcschemes", isDirectory: true)
        let userData = containerURL.appendingPathComponent("xcuserdata", isDirectory: true)
        var schemeURLs: [URL] = []

        if let urls = try? FileManager.default.contentsOfDirectory(at: sharedSchemes, includingPropertiesForKeys: nil) {
            schemeURLs.append(contentsOf: urls)
        }
        if let enumerator = FileManager.default.enumerator(at: userData, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator where url.pathExtension == "xcscheme" {
                schemeURLs.append(url)
            }
        }

        return schemeURLs
            .filter { $0.pathExtension == "xcscheme" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { !$0.isEmpty }
    }

    private func gitMetadata(at path: String, detectWorktree: Bool) -> (branch: String?, root: String?, isWorktree: Bool, worktreeName: String?, mainPath: String?) {
        let root = Shell.run("git rev-parse --show-toplevel", in: path).stdout
        guard !root.isEmpty else { return (nil, nil, false, nil, nil) }
        let branchOutput = Shell.run("git branch --show-current", in: path).stdout
        let branch: String = branchOutput.isEmpty ? Shell.run("git rev-parse --short HEAD", in: path).stdout : branchOutput

        guard detectWorktree else { return (branch, root, false, nil, nil) }
        let commonDir = Shell.run("git rev-parse --git-common-dir", in: path).stdout
        let gitDir = Shell.run("git rev-parse --git-dir", in: path).stdout
        let isWorktree = !commonDir.isEmpty && !gitDir.isEmpty && commonDir != gitDir
        let worktreeName = isWorktree ? URL(fileURLWithPath: root).lastPathComponent : nil
        let mainPath: String? = isWorktree ? Shell.run("git worktree list --porcelain | awk '/^worktree / {print $2; exit}'", in: path).stdout : nil
        return (branch.isEmpty ? nil : branch, root, isWorktree, worktreeName, mainPath?.isEmpty == false ? mainPath : nil)
    }
}

private struct ProjectCandidate {
    var rootPath: String
    var workspacePath: String?
    var xcodeprojPath: String?
    var packagePath: String?
    var podfilePath: String?

    var hasProjectSignal: Bool {
        workspacePath != nil || xcodeprojPath != nil || packagePath != nil || podfilePath != nil
    }
}
