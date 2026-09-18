import SwiftUI
import UniformTypeIdentifiers
import AppKit

private enum Metrics {
    static let sidebarWidth: CGFloat = 248
    static let labelWidth: CGFloat = 92
    static let outerPad: CGFloat = 16
    static let rowRadius: CGFloat = 8
}

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Metrics.outerPad)
                .padding(.top, 14)
                .padding(.bottom, 10)
            Divider()
            HStack(spacing: 0) {
                sidebar
                    .frame(width: Metrics.sidebarWidth)
                    .frame(maxHeight: .infinity)
                Divider()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: $appState.isDropTargeted, perform: handleDrop)
        .confirmationDialog(
            appState.confirmTitle,
            isPresented: $appState.showTrashConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                appState.confirmTrash()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apps are cleaned one at a time. Restore anything from Trash. LocusSweep never uses rm.")
        }
        .sheet(isPresented: $appState.showSummary) {
            CleanSummarySheet()
                .environmentObject(appState)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LocusSweep")
                    .font(.title2.weight(.semibold))
                Text(appState.progressLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(appState.settings.safetyLevel.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
                .help(appState.settings.safetyLevel.detail)
            if appState.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Scanning")
            }
            Button("Choose Apps…") { appState.chooseApps() }
                .disabled(appState.isTrashing)
            Button("Scan") { appState.rescanQueue() }
                .disabled(appState.queue.isEmpty || appState.isScanning || appState.isTrashing)
                .help("Scan every app in the queue, one at a time.")
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Scan scope and safety level")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Queue")
                    .font(.headline)
                Spacer()
                Text("\(appState.queue.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if appState.queue.isEmpty {
                Text("Drop .app bundles here. They scan one by one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.queue) { entry in
                            QueueRow(entry: entry, isSelected: entry.id == appState.activeID) {
                                appState.select(entry.id)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }

            Divider()
            HStack {
                Button("Clear") { appState.clear() }
                    .disabled(appState.queue.isEmpty || appState.isScanning || appState.isTrashing)
                Spacer()
            }
            .padding(10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var detail: some View {
        if appState.queue.isEmpty {
            emptyDrop
        } else if let entry = appState.activeApp {
            appDetail(entry)
        } else {
            Text("Select an app in the queue.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyDrop: some View {
        VStack(spacing: 12) {
            dropChrome(compact: false)
            if let err = appState.errorMessage {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460)
            } else {
                Text("Drop one or more .app bundles, or choose them. Leftovers are listed before anything goes to Trash.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
        }
        .padding(Metrics.outerPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func appDetail(_ entry: QueuedApp) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let err = appState.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            appSummary(entry)

            if appState.showPermissionGuide {
                PermissionBanner(
                    issues: appState.accessIssues,
                    settingsOpenFailed: appState.settingsOpenFailed,
                    onOpenSettings: { appState.openPermissionSettings() },
                    onScanAgain: { appState.rescanQueue() },
                    onDismiss: { appState.dismissPermissionGuide() }
                )
            }

            results(entry)
        }
        .padding(Metrics.outerPad)
    }

    private func appSummary(_ entry: QueuedApp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.info.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.phase.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                labeled("Bundle ID", entry.info.bundleIdentifier)
                labeled("Path", entry.info.path)
                if let version = entry.info.shortVersion {
                    labeled("Version", version)
                }
            }
            if let note = entry.failureMessage {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    @ViewBuilder
    private func results(_ entry: QueuedApp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Leftovers")
                    .font(.headline)
                    .fixedSize()
                if entry.phase == .ready || entry.phase == .cleaned {
                    Text("\(entry.items.count) · \(ResidueSummary.aggregating(entry.items).formattedSize)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
            }
            HStack(spacing: 8) {
                Button("All") { appState.selectAll(true) }
                    .disabled(entry.items.isEmpty || entry.phase != .ready)
                Button("None") { appState.selectAll(false) }
                    .disabled(entry.items.isEmpty || entry.phase != .ready)
                Spacer(minLength: 8)
                if appState.cleanableCount > 1 {
                    Button("Clean Queue…") { appState.requestTrash(.queue) }
                        .disabled(appState.isTrashing || appState.isScanning)
                        .fixedSize()
                        .help("Trash checked leftovers one app at a time, in queue order.")
                }
                Button("Move to Trash…") { appState.requestTrash(.current) }
                    .disabled(entry.checkedPaths.isEmpty || entry.phase != .ready || appState.isTrashing || appState.isScanning)
                    .fixedSize()
                    .keyboardShortcut(.defaultAction)
            }

            if entry.phase == .scanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Scanning \(entry.info.name)…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else if entry.phase == .pending {
                Text("Waiting. The queue scans one app at a time.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if entry.phase == .cleaning {
                Text("Moving checked items to Trash…")
                    .foregroundStyle(.secondary)
            } else if entry.items.isEmpty {
                Text(emptyCopy(entry))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List {
                    ForEach(entry.items) { item in
                        ResidueRowView(
                            item: item,
                            isOn: Binding(
                                get: { appState.activeApp?.checkedPaths.contains(item.path) ?? false },
                                set: { appState.setChecked(path: item.path, on: $0) }
                            )
                        )
                        .disabled(entry.phase != .ready)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minHeight: 180, maxHeight: .infinity)

                HStack {
                    Text("Checked: \(entry.checkedItems.count) · \(ResidueSummary.aggregating(entry.checkedItems).formattedSize)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            Text("Safety filter skips Apple and system paths. Moves go to Trash only.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func emptyCopy(_ entry: QueuedApp) -> String {
        if entry.phase == .skipped {
            return entry.failureMessage ?? "Skipped."
        }
        if entry.phase == .cleaned {
            if let summary = entry.cleanedSummary, summary.itemCount > 0 {
                return "Moved \(summary.itemCount) item(s) (\(summary.formattedSize)) to Trash."
            }
            return "Nothing left for this app."
        }
        if appState.accessIssues.isEmpty {
            return "No leftovers in the current scan scope."
        }
        return "No readable leftovers in the current scope. Protected folders still need access — use the guide above, then scan again."
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: Metrics.labelWidth, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dropChrome(compact: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                appState.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
            )
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appState.isDropTargeted ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05))
            )
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: compact ? 22 : 34))
                        .foregroundStyle(.secondary)
                    Text(compact ? "Drop more apps" : "Drop .app bundles")
                        .font(compact ? .callout.weight(.medium) : .headline)
                    if !compact {
                        Text("or choose them. Several apps stay in a queue and run one at a time.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: compact ? .infinity : 520)
            .frame(height: compact ? 72 : 168)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let usable = providers.contains { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard usable else { return false }
        appState.ingestProviders(providers)
        return true
    }
}

private struct QueueRow: View {
    let entry: QueuedApp
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.info.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(entry.info.bundleIdentifier)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.rowRadius, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.info.name), \(entry.phase.label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var symbol: String {
        switch entry.phase {
        case .pending: return "circle"
        case .scanning: return "arrow.triangle.2.circlepath"
        case .ready: return "checklist"
        case .cleaning: return "trash"
        case .cleaned: return "checkmark.circle"
        case .failed: return "exclamationmark.triangle"
        case .skipped: return "minus.circle"
        }
    }

    private var subtitle: String {
        switch entry.phase {
        case .ready, .cleaning:
            let summary = ResidueSummary.aggregating(entry.items)
            return "\(entry.phase.label) · \(summary.itemCount) · \(summary.formattedSize)"
        case .cleaned:
            if let summary = entry.cleanedSummary {
                return "Cleaned · \(summary.itemCount) · \(summary.formattedSize)"
            }
            return entry.phase.label
        default:
            return entry.phase.label
        }
    }
}

private struct ResidueRowView: View {
    let item: ScannedResidue
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.category.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(item.formattedSize)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                Text(item.path)
                    .font(.callout.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text("matched by \(item.matchedBy)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .toggleStyle(.checkbox)
        .padding(.vertical, 2)
    }
}

private struct CleanSummarySheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var needsPermission: Bool {
        appState.lastFailures.contains(where: \.permissionDenied)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleanup summary")
                .font(.title2.weight(.semibold))

            if let summary = appState.lastSummary {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Apps")
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        Text("\(appState.lastCleanedAppCount)")
                            .font(.title3.monospacedDigit())
                    }
                    GridRow {
                        Text("Moved to Trash")
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        Text("\(summary.itemCount)")
                            .font(.title3.monospacedDigit())
                    }
                    GridRow {
                        Text("Volume")
                            .foregroundStyle(.secondary)
                            .frame(width: 140, alignment: .leading)
                        Text(summary.formattedSize)
                            .font(.title3.monospacedDigit())
                    }
                }
            } else {
                Text("No items were moved.")
                    .foregroundStyle(.secondary)
            }

            if !appState.lastFailures.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Still in place")
                        .font(.headline)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(appState.lastFailures, id: \.self) { failure in
                                Text("\(failure.path): \(failure.message)")
                                    .font(.caption)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }

            if needsPermission {
                Text("macOS blocked at least one item. Grant Full Disk Access, then scan again and retry. Already moved items stay in Trash.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Restore items from Trash in Finder if you need them back.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if needsPermission {
                    Button("Open System Settings") {
                        appState.openPermissionSettings()
                    }
                }
                Spacer(minLength: 8)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 460, idealWidth: 500, maxWidth: 560)
    }
}
