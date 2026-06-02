import Foundation

struct PersistenceStore {
    private var settingsURL: URL {
        appSupportDirectory.appendingPathComponent("settings.json")
    }

    private var projectsCacheURL: URL {
        appSupportDirectory.appendingPathComponent("projects-cache.json")
    }

    private var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("XcodeBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL) else {
            return AppSettings()
        }
        return (try? JSONDecoder().decode(AppSettings.self, from: data)) ?? AppSettings()
    }

    func save(settings: AppSettings) {
        guard let data = try? JSONEncoder.pretty.encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    func loadProjectsCache() -> [ProjectItem] {
        guard let data = try? Data(contentsOf: projectsCacheURL) else {
            return []
        }
        return (try? JSONDecoder().decode([ProjectItem].self, from: data)) ?? []
    }

    func saveProjectsCache(_ projects: [ProjectItem]) {
        guard let data = try? JSONEncoder.pretty.encode(projects) else { return }
        try? data.write(to: projectsCacheURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
