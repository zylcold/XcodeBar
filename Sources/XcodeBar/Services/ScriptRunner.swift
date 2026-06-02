import Foundation

struct ScriptRunner {
    func run(script: ScriptAction, project: ProjectItem?) -> ScriptResult {
        let start = Date()
        let workingDirectory = script.workingDirectory?.isEmpty == false ? script.workingDirectory! : (project?.rootPath ?? FileManager.default.homeDirectoryForCurrentUser.path)
        let output = Shell.run(script.command, in: workingDirectory)
        return ScriptResult(
            scriptName: script.name,
            command: script.command,
            workingDirectory: workingDirectory,
            stdout: output.stdout,
            stderr: output.stderr,
            exitCode: output.exitCode,
            duration: Date().timeIntervalSince(start)
        )
    }
}
