import SwiftUI

@main
struct XcodeBarApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(state)
                .frame(width: 460)
        } label: {
            MenuBarLabelView(isScanning: state.isScanning)
        }
        .menuBarExtraStyle(.window)

        Window("XcodeBar", id: "main") {
            ProjectListView()
                .environmentObject(state)
                .frame(minWidth: 980, minHeight: 620)
                .background(WindowFocusView())
                .task {
                    if state.projects.isEmpty {
                        state.refreshAll()
                    }
                }
        }

        Window("设置", id: "settings") {
            SettingsView()
                .environmentObject(state)
                .frame(width: 760, height: 620)
                .background(WindowFocusView())
        }

        Window("脚本结果", id: "scriptResult") {
            if let result = state.lastScriptResult {
                ScriptResultView(result: result)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(state)
                .frame(width: 760, height: 620)
        }
    }
}
