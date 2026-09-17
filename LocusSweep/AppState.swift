import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// One row in the scan results list (default checked).
struct ResidueRow: Identifiable, Equatable {
    var id: String { item.path }
    var item: ScannedResidue
    var isChecked: Bool
}

@MainActor
final class AppState: ObservableObject {
    @Published var selected: AppBundleInfo?
    @Published var rows: [ResidueRow] = []
    @Published var isScanning = false
    @Published var isTrashing = false
    @Published var errorMessage: String?
    @Published var isDropTargeted = false
    @Published var showTrashConfirm = false
    @Published var showSummary = false
    @Published var lastSummary: ResidueSummary?
    @Published var lastFailures: [String] = []

    var scanSummary: ResidueSummary {
        ResidueSummary.aggregating(rows.map(\.item))
    }

    var checkedRows: [ResidueRow] {
        rows.filter(\.isChecked)
    }

    var checkedSummary: ResidueSummary {
        ResidueSummary.aggregating(checkedRows.map(\.item))
    }

    func ingest(url: URL) {
        do {
            let info = try AppBundleReader.read(url: url)
            selected = info
            errorMessage = nil
            lastSummary = nil
            lastFailures = []
            showSummary = false
            rows = []
            Task { await rescan() }
        } catch {
            selected = nil
            rows = []
            errorMessage = error.localizedDescription
        }
    }

    func rescan() async {
        guard let info = selected else {
            rows = []
            return
        }
        isScanning = true
        defer { isScanning = false }

        let scanned = await Task.detached(priority: .userInitiated) {
            ResidueScanner.scan(for: info, includeAppBundle: true)
        }.value

        rows = scanned.map { ResidueRow(item: $0, isChecked: true) }
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
        rows = []
        errorMessage = nil
        lastSummary = nil
        lastFailures = []
        showSummary = false
        showTrashConfirm = false
    }

    func selectAll(_ on: Bool) {
        for i in rows.indices {
            rows[i].isChecked = on
        }
    }

    func requestTrashChecked() {
        guard !checkedRows.isEmpty else { return }
        showTrashConfirm = true
    }

    func confirmTrashChecked() {
        showTrashConfirm = false
        let targets = checkedRows
        guard !targets.isEmpty else { return }
        isTrashing = true
        let paths = targets.map(\.item.path)
        let sizes = Dictionary(uniqueKeysWithValues: targets.map { ($0.item.path, $0.item.byteSize) })
        let result = TrashMover.moveToTrash(paths: paths, byteSizes: sizes)
        isTrashing = false

        lastSummary = result.summary
        lastFailures = result.failed.map { "\($0.path): \($0.message)" }
        showSummary = true

        // Drop moved rows from the list
        let moved = Set(result.moved)
        rows.removeAll { moved.contains($0.item.path) }
    }
}
