import AppKit
import Foundation

struct ScriptRunner {
    func run(script: ScriptAction, project: ProjectItem?) -> ScriptResult {
        let start = Date()
        let workingDirectory = script.workingDirectory?.isEmpty == false
            ? script.workingDirectory!
            : (project?.rootPath ?? FileManager.default.homeDirectoryForCurrentUser.path)

        let escapedDir = workingDirectory
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "'\\''")

        let escapedCmd = script.command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        // Open Terminal at the working directory, then type the command (without executing)
        let appleScript = """
        tell application "Terminal"
            activate
            do script "cd '\\(escapedDir)'"
            delay 0.3
            tell application "System Events"
                keystroke "\(escapedCmd)"
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)
        }

        let exitCode: Int32 = error == nil ? 0 : 1
        let stderr = error?.description ?? ""

        return ScriptResult(
            scriptName: script.name,
            command: script.command,
            workingDirectory: workingDirectory,
            stdout: "",
            stderr: stderr,
            exitCode: exitCode,
            duration: Date().timeIntervalSince(start)
        )
    }
}
