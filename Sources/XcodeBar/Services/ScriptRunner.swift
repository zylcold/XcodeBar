import AppKit
import Foundation

struct ScriptRunner {
    func run(script: ScriptAction, project: ProjectItem?) -> ScriptResult {
        let start = Date()
        let workingDirectory = script.workingDirectory?.isEmpty == false
            ? script.workingDirectory!
            : (project?.rootPath ?? FileManager.default.homeDirectoryForCurrentUser.path)

        let shellCommand = "cd \(shellQuoted(workingDirectory)) && \(script.command); exec /bin/zsh -l"
        let terminalCommand = "/bin/zsh -lic \(shellQuoted(shellCommand))"
        let escapedCommand = appleScriptEscaped(terminalCommand)
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
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

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
