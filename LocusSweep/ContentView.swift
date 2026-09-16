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
                .frame(height: 140)

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

                GroupBox("Candidate residue paths (\(appState.residueCandidates.count))") {
                    if appState.residueCandidates.isEmpty {
                        Text("No candidate paths (blocked system bundle or empty id). Full disk scan arrives later.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                    } else {
                        List(appState.residueCandidates) { cand in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cand.category.displayName)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(cand.path)
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                                Text("matched by \(cand.matchedBy)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                        .frame(minHeight: 180, maxHeight: 320)
                    }
                }

                Text("Paths are rule-based candidates only — existence and size scan is a later work item.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let err = appState.errorMessage {
                Text(err)
                    .foregroundStyle(.red)
            } else {
                Text("Drop an .app here or choose one to read Bundle ID and install path.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
