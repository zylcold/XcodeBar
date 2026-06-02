import AppKit
import Foundation

enum ProjectOpener {
    static func open(project: ProjectItem, target: OpenTarget) {
        let filePath = target == .finder || target == .terminal ? project.rootPath : project.preferredOpenPath
        let quotedPath = shellQuote(filePath)

        switch target {
        case .xcode:
            NSWorkspace.shared.open(URL(fileURLWithPath: project.preferredOpenPath))
        case .finder:
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.rootPath)])
        case .terminal:
            _ = Shell.run("open -a Terminal \(quotedPath)")
        case .vscode:
            _ = Shell.run("open -a 'Visual Studio Code' \(quotedPath)")
        case .cursor:
            _ = Shell.run("open -a Cursor \(quotedPath)")
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
