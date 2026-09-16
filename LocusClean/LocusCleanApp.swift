import SwiftUI
import AppKit

@main
struct LocusCleanApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("LocusClean") {
            ContentView()
                .environmentObject(appState)
        }
        .defaultSize(width: 640, height: 420)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About LocusClean") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .applicationName: "LocusClean",
                    ])
                }
            }
            CommandGroup(after: .newItem) {
                Button("Choose App…") {
                    appState.chooseApp()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }

        Settings {
            Form {
                Text("LocusClean — drag-to-inspect .app bundles")
                Text("Residue scan arrives in later work items.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(width: 360, height: 120)
        }
    }
}
