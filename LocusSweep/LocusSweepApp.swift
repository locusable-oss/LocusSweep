import SwiftUI
import AppKit

@main
struct LocusSweepApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("LocusSweep") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 920, minHeight: 600)
        }
        .defaultSize(width: 980, height: 720)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About LocusSweep") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "LocusSweep",
                    ])
                }
            }
            CommandGroup(after: .newItem) {
                Button("Choose Apps…") {
                    appState.chooseApps()
                }
                .keyboardShortcut("o", modifiers: [.command])
                Button("Scan Queue") {
                    appState.rescanQueue()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(appState.queue.isEmpty || appState.isScanning || appState.isTrashing)
                Button("Move Checked to Trash…") {
                    appState.requestTrash(.current)
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(!appState.canTrashCurrent)
                Button("Clean Queue…") {
                    appState.requestTrash(.queue)
                }
                .keyboardShortcut(.delete, modifiers: [.command, .shift])
                .disabled(appState.cleanableCount == 0)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
