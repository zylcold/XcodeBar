import SwiftUI

@main
struct XcodeBarApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(state)
                .frame(width: 380)
        } label: {
            MenuBarLabelView(title: state.menuTitle, showIcon: state.settings.menuBar.showIcon)
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

        Settings {
            SettingsView()
                .environmentObject(state)
                .frame(width: 760, height: 620)
        }
    }
}
