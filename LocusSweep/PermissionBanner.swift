import SwiftUI

struct PermissionBanner: View {
    let issues: [AccessIssue]
    var settingsOpenFailed: Bool
    var onOpenSettings: () -> Void
    var onScanAgain: () -> Void
    var onDismiss: () -> Void

    private var kind: AccessKind {
        issues.first?.kind ?? .fullDiskAccess
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text(PermissionGuide.title(for: kind))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(PermissionGuide.summary(issues: issues))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(PermissionGuide.steps(for: kind).enumerated()), id: \.offset) { index, step in
                    Text("\(index + 1). \(step)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if issues.count > 1 {
                Text(issues.map(\.path).joined(separator: "\n"))
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if settingsOpenFailed {
                Text("System Settings did not open. Paste this into Safari or Spotlight, then scan again:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(PermissionGuide.settingsURLs(for: kind).first?.absoluteString ?? PermissionGuide.fullDiskAccessURLString)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .center, spacing: 8) {
                Button("Open System Settings", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
                    .fixedSize()
                Button("Scan Again", action: onScanAgain)
                    .fixedSize()
                Spacer(minLength: 12)
                Button("Dismiss", action: onDismiss)
                    .fixedSize()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}
