import Foundation

/// Where one app sits in the lightweight queue. Work runs one app at a time.
public enum QueuePhase: String, Codable, Sendable, Equatable, CaseIterable {
    case pending
    case scanning
    case ready
    case cleaning
    case cleaned
    case failed
    case skipped

    public var isBusy: Bool { self == .scanning || self == .cleaning }

    public var label: String {
        switch self {
        case .pending: return "Pending"
        case .scanning: return "Scanning"
        case .ready: return "Ready"
        case .cleaning: return "Cleaning"
        case .cleaned: return "Cleaned"
        case .failed: return "Failed"
        case .skipped: return "Skipped"
        }
    }
}

public struct QueuedApp: Equatable, Sendable, Identifiable {
    public var info: AppBundleInfo
    public var phase: QueuePhase
    public var items: [ScannedResidue]
    public var checkedPaths: Set<String>
    public var accessIssues: [AccessIssue]
    public var failureMessage: String?
    public var cleanedSummary: ResidueSummary?

    public var id: String { info.id }

    public init(
        info: AppBundleInfo,
        phase: QueuePhase,
        items: [ScannedResidue] = [],
        checkedPaths: Set<String> = [],
        accessIssues: [AccessIssue] = [],
        failureMessage: String? = nil,
        cleanedSummary: ResidueSummary? = nil
    ) {
        self.info = info
        self.phase = phase
        self.items = items
        self.checkedPaths = checkedPaths
        self.accessIssues = accessIssues
        self.failureMessage = failureMessage
        self.cleanedSummary = cleanedSummary
    }

    public var checkedItems: [ScannedResidue] {
        items.filter { checkedPaths.contains($0.path) }
    }
}

/// Sequential multi-app queue. Never returns a next item while another is scanning or cleaning.
public enum AppQueue {
    public static func enqueue(_ incoming: [AppBundleInfo], into queue: [QueuedApp]) -> [QueuedApp] {
        var out = queue
        var seen = Set(out.map(\.id))
        for info in incoming {
            if seen.insert(info.id).inserted {
                out.append(QueuedApp(info: info, phase: .pending))
            }
        }
        return out
    }

    public static func busyCount(_ queue: [QueuedApp]) -> Int {
        queue.reduce(0) { $0 + ($1.phase.isBusy ? 1 : 0) }
    }

    /// First pending app, or nil when something is already scanning/cleaning.
    public static func nextToScan(_ queue: [QueuedApp]) -> QueuedApp? {
        guard busyCount(queue) == 0 else { return nil }
        return queue.first { $0.phase == .pending }
    }

    /// Ready apps that still have checked leftovers, in queue order. Empty if any app is busy.
    public static func cleanOrder(_ queue: [QueuedApp]) -> [String] {
        guard busyCount(queue) == 0 else { return [] }
        return queue.filter { $0.phase == .ready && !$0.checkedPaths.isEmpty }.map(\.id)
    }

    public static func update(
        _ id: String,
        in queue: [QueuedApp],
        _ body: (inout QueuedApp) -> Void
    ) -> [QueuedApp] {
        var out = queue
        guard let index = out.firstIndex(where: { $0.id == id }) else { return out }
        body(&out[index])
        return out
    }
}
