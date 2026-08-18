import AppKit
import Foundation

struct ScriptRunner {
    func run(script: ScriptAction, project: ProjectItem?) -> ScriptResult {
        let workingDirectory = script.workingDirectory?.isEmpty == false
            ? script.workingDirectory!
            : (project?.rootPath ?? FileManager.default.homeDirectoryForCurrentUser.path)

        if script.showsExecutionWindow {
            return runInTerminal(script: script, workingDirectory: workingDirectory)
        }
        return runCaptured(script: script, workingDirectory: workingDirectory)
    }

    /// 在 Terminal.app 中交互式执行，返回启动结果（无法捕获真实 stdout/exit code）。
    private func runInTerminal(script: ScriptAction, workingDirectory: String) -> ScriptResult {
        let start = Date()
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

    /// 无窗口后台执行并捕获真实 stdout/stderr/exit code。
    private func runCaptured(script: ScriptAction, workingDirectory: String) -> ScriptResult {
        let start = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", script.command]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ScriptResult(
                scriptName: script.name,
                command: script.command,
                workingDirectory: workingDirectory,
                stdout: "",
                stderr: error.localizedDescription,
                exitCode: 127,
                duration: Date().timeIntervalSince(start)
            )
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return ScriptResult(
            scriptName: script.name,
            command: script.command,
            workingDirectory: workingDirectory,
            stdout: stdout.trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
            exitCode: process.terminationStatus,
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
