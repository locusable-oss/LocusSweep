import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var selected: AppBundleInfo?
    @Published var residueCandidates: [ResidueCandidate] = []
    @Published var errorMessage: String?
    @Published var isDropTargeted = false

    func ingest(url: URL) {
        do {
            let info = try AppBundleReader.read(url: url)
            selected = info
            residueCandidates = ResidueRules.candidatePaths(for: info)
            errorMessage = nil
        } catch {
            selected = nil
            residueCandidates = []
            errorMessage = error.localizedDescription
        }
    }

    func chooseApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.message = "Choose a .app to inspect"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        ingest(url: url)
    }

    func clear() {
        selected = nil
        residueCandidates = []
        errorMessage = nil
    }
}
