import Foundation

/// A residue candidate that exists on disk, with measured size.
public struct ScannedResidue: Equatable, Sendable, Identifiable, Hashable {
    public var id: String { path }
    public var path: String
    public var category: ResidueCategory
    public var matchedBy: String
    public var byteSize: UInt64

    public init(path: String, category: ResidueCategory, matchedBy: String, byteSize: UInt64) {
        self.path = path
        self.category = category
        self.matchedBy = matchedBy
        self.byteSize = byteSize
    }

    public init(candidate: ResidueCandidate, byteSize: UInt64) {
        self.path = candidate.path
        self.category = candidate.category
        self.matchedBy = candidate.matchedBy
        self.byteSize = byteSize
    }

    public var formattedSize: String { ByteFormat.string(byteSize) }
}

/// Aggregate totals after a scan or clean.
public struct ResidueSummary: Equatable, Sendable {
    public var itemCount: Int
    public var totalBytes: UInt64

    public init(itemCount: Int, totalBytes: UInt64) {
        self.itemCount = itemCount
        self.totalBytes = totalBytes
    }

    public var formattedSize: String { ByteFormat.string(totalBytes) }

    public static func aggregating(_ items: [ScannedResidue]) -> ResidueSummary {
        ResidueSummary(
            itemCount: items.count,
            totalBytes: items.reduce(UInt64(0)) { $0 &+ $1.byteSize }
        )
    }
}
