import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.title2.weight(.semibold))
                    Text("Scan scope and safety apply on the next scan. Apple and system paths stay blocked at every level.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GroupBox("Safety level") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(SafetyLevel.allCases, id: \.self) { level in
                            safetyRow(level)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Scan scope") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Include the .app bundle", isOn: includeAppBinding)
                        Text("Off keeps the application in place and only lists leftovers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20)
                        Divider()
                        ForEach(ResidueCategory.libraryCategories, id: \.self) { category in
                            Toggle(category.displayName, isOn: categoryBinding(category))
                        }
                        if appState.settings.enabledCategories.isEmpty && !appState.settings.includeAppBundle {
                            Text("Turn on at least one folder, or scans have nothing to look at.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .center, spacing: 12) {
                    Button("Restore Defaults") {
                        appState.restoreDefaultSettings()
                    }
                    Spacer(minLength: 12)
                    Button("Rescan Queue") {
                        appState.rescanQueue()
                    }
                    .disabled(appState.queue.isEmpty || appState.isScanning || appState.isTrashing)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 520, height: 640)
    }

    private var includeAppBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.includeAppBundle },
            set: { appState.setIncludeAppBundle($0) }
        )
    }

    private func categoryBinding(_ category: ResidueCategory) -> Binding<Bool> {
        Binding(
            get: { appState.settings.enabledCategories.contains(category) },
            set: { appState.setCategory(category, enabled: $0) }
        )
    }

    @ViewBuilder
    private func safetyRow(_ level: SafetyLevel) -> some View {
        let selected = appState.settings.safetyLevel == level
        Button {
            appState.setSafetyLevel(level)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(level.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel("\(level.title). \(level.detail)")
    }
}
