import SwiftUI
import AppKit

@main
struct LocusSweepApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("LocusSweep") {
            ContentView()
                .environmentObject(appState)
        }
        .defaultSize(width: 780, height: 640)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About LocusSweep") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "LocusSweep",
                    ])
                }
            }
            CommandGroup(after: .newItem) {
                Button("Choose App…") {
                    appState.chooseApp()
                }
                .keyboardShortcut("o", modifiers: [.command])
                Button("Move Checked to Trash…") {
                    appState.requestTrashChecked()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
            }
        }

        Settings {
            Form {
                Text("LocusSweep — drop an .app, scan leftovers, move to Trash.")
                Text("Safety filter skips Apple/system paths. Never uses rm -rf.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 400, height: 120)
        }
    }
}
