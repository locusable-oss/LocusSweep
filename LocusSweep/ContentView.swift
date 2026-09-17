import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("LocusSweep")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Choose App…") { appState.chooseApp() }
                if appState.selected != nil {
                    Button("Clear", role: .destructive) { appState.clear() }
                }
            }

            DropZone()
                .frame(maxWidth: .infinity)
                .frame(height: 120)

            if let info = appState.selected {
                GroupBox("Selected app") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        row("Name", info.name)
                        row("Bundle ID", info.bundleIdentifier)
                        row("Path", info.path)
                        if let v = info.shortVersion { row("Version", v) }
                        if let b = info.bundleVersion { row("Build", b) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(4)
                }

                residueListSection

                HStack {
                    Text("Safety filter skips com.apple.* and system paths. Moves go to Trash only (never rm).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if let err = appState.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
            } else {
                Text("Drop an .app here or choose one to scan leftover files.")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            "Move \(appState.checkedRows.count) item(s) (\(appState.checkedSummary.formattedSize)) to Trash?",
            isPresented: $appState.showTrashConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                appState.confirmTrashChecked()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Items can be restored from Trash. LocusSweep never permanently deletes with rm.")
        }
        .sheet(isPresented: $appState.showSummary) {
            CleanSummarySheet()
                .environmentObject(appState)
        }
    }

    @ViewBuilder
    private var residueListSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(listTitle)
                        .font(.headline)
                    Spacer()
                    if appState.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Button("All") { appState.selectAll(true) }
                        .disabled(appState.rows.isEmpty)
                    Button("None") { appState.selectAll(false) }
                        .disabled(appState.rows.isEmpty)
                    Button("Rescan") {
                        Task { await appState.rescan() }
                    }
                    .disabled(appState.isScanning || appState.isTrashing)
                    Button("Move to Trash…") {
                        appState.requestTrashChecked()
                    }
                    .disabled(appState.checkedRows.isEmpty || appState.isTrashing || appState.isScanning)
                    .keyboardShortcut(.defaultAction)
                }

                if appState.rows.isEmpty && !appState.isScanning {
                    Text("No existing residue found (or all candidates filtered as unsafe).")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                } else {
                    List {
                        ForEach($appState.rows) { $row in
                            ResidueRowView(row: $row)
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .frame(minHeight: 200, maxHeight: 360)

                    HStack {
                        Text("Checked: \(appState.checkedRows.count) · \(appState.checkedSummary.formattedSize)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Found: \(appState.rows.count) · \(appState.scanSummary.formattedSize)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Text("Scan results")
        }
    }

    private var listTitle: String {
        if appState.isScanning { return "Scanning…" }
        if appState.isTrashing { return "Moving to Trash…" }
        return "\(appState.rows.count) item(s) · \(appState.scanSummary.formattedSize)"
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
        }
    }
}

private struct ResidueRowView: View {
    @Binding var row: ResidueRow

    var body: some View {
        Toggle(isOn: $row.isChecked) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(row.item.category.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(row.item.formattedSize)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text(row.item.path)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(2)
                    Text("matched by \(row.item.matchedBy)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 2)
    }
}

private struct CleanSummarySheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleanup summary")
                .font(.title2.weight(.semibold))

            if let summary = appState.lastSummary {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        Text("Items moved to Trash")
                            .foregroundStyle(.secondary)
                        Text("\(summary.itemCount)")
                            .font(.title3.monospacedDigit())
                    }
                    GridRow {
                        Text("Volume")
                            .foregroundStyle(.secondary)
                        Text(summary.formattedSize)
                            .font(.title3.monospacedDigit())
                    }
                }
            } else {
                Text("No items were moved.")
                    .foregroundStyle(.secondary)
            }

            if !appState.lastFailures.isEmpty {
                GroupBox("Some items failed") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.lastFailures, id: \.self) { line in
                            Text(line)
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Text("You can restore items from Trash in Finder if needed.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct DropZone: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
                appState.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.4),
                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
            )
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(appState.isDropTargeted ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
            )
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Drop .app here")
                        .font(.headline)
                    Text("or click Choose App…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $appState.isDropTargeted, perform: handleDrop)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let str = item as? String {
                url = URL(fileURLWithPath: str)
            } else if let u = item as? URL {
                url = u
            } else {
                url = nil
            }
            guard let url else { return }
            Task { @MainActor in
                appState.ingest(url: url)
            }
        }
        return true
    }
}
