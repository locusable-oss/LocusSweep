import Foundation

/// Items that exist, plus permission failures the UI can recover from.
public struct ScanReport: Equatable, Sendable {
    public var items: [ScannedResidue]
    public var accessIssues: [AccessIssue]

    public init(items: [ScannedResidue], accessIssues: [AccessIssue]) {
        self.items = items
        self.accessIssues = PermissionGuide.normalized(accessIssues)
    }
}

/// Scans rule-based candidates for existence and aggregates on-disk sizes.
public enum ResidueScanner {
    public struct Options {
        public var fileManager: FileManager
        public var homeDirectory: URL

        public init(
            fileManager: FileManager = .default,
            homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
        ) {
            self.fileManager = fileManager
            self.homeDirectory = homeDirectory
        }
    }

    /// Walk candidates, keep those that exist, measure recursive byte size, apply safety filter.
    public static func scan(
        candidates: [ResidueCandidate],
        options: Options = Options()
    ) -> [ScannedResidue] {
        scanReport(candidates: candidates, options: options).items
    }

    public static func scanReport(
        candidates: [ResidueCandidate],
        options: Options = Options(),
        settings: SweepSettings = .default
    ) -> ScanReport {
        var issues = probeIssues(options: options, settings: settings)
        // The caller decides whether the .app bundle is in the list. Other categories follow settings.
        let scoped = candidates.filter { $0.category == .application || settings.allows(category: $0.category) }
        let safe = SafetyFilter.filter(scoped, homeDirectory: options.homeDirectory, safetyLevel: settings.safetyLevel)

        var out: [ScannedResidue] = []
        out.reserveCapacity(safe.count)
        for cand in safe {
            var isDir: ObjCBool = false
            if !options.fileManager.fileExists(atPath: cand.path, isDirectory: &isDir) {
                if let issue = PermissionGuide.probeDirectory(
                    cand.path,
                    fileManager: options.fileManager,
                    homeDirectory: options.homeDirectory
                ) {
                    issues.append(issue)
                }
                continue
            }
            let size = measure(
                path: cand.path,
                fileManager: options.fileManager,
                homeDirectory: options.homeDirectory,
                issues: &issues
            )
            out.append(ScannedResidue(candidate: cand, byteSize: size))
        }

        let items = out.sorted { lhs, rhs in
            if lhs.category.displayName != rhs.category.displayName {
                return lhs.category.displayName < rhs.category.displayName
            }
            return lhs.path < rhs.path
        }
        return ScanReport(items: items, accessIssues: issues)
    }

    /// Scan from app info: build rule candidates → safety filter → size.
    public static func scan(
        for info: AppBundleInfo,
        includeAppBundle: Bool = true,
        options: Options = Options()
    ) -> [ScannedResidue] {
        scanReport(for: info, includeAppBundle: includeAppBundle, options: options).items
    }

    public static func scanReport(
        for info: AppBundleInfo,
        includeAppBundle: Bool? = nil,
        options: Options = Options(),
        settings: SweepSettings = .default
    ) -> ScanReport {
        // Defense in depth: Apple / system bundle IDs are never proposed, including the .app itself.
        if ResidueRules.isBlockedBundleID(info.bundleIdentifier) {
            return ScanReport(items: [], accessIssues: [])
        }

        let include = includeAppBundle ?? settings.includeAppBundle
        var issues: [AccessIssue] = []
        var candidates = ResidueRules.candidatePaths(for: info, homeDirectory: options.homeDirectory, settings: settings)
        candidates.append(contentsOf: relatedCandidates(
            bundleID: info.bundleIdentifier,
            options: options,
            settings: settings,
            issues: &issues
        ))

        if include {
            candidates.insert(
                ResidueCandidate(path: info.path, category: .application, matchedBy: "appBundle"),
                at: 0
            )
        }

        var seen = Set<String>()
        candidates = candidates.filter { seen.insert($0.path).inserted }

        let report = scanReport(candidates: candidates, options: options, settings: settings)
        return ScanReport(items: report.items, accessIssues: issues + report.accessIssues)
    }

    /// Recursive byte size of a file or directory. Symlinks are not followed as directories.
    public static func byteSize(of path: String, fileManager: FileManager = .default) -> UInt64 {
        var ignored: [AccessIssue] = []
        return measure(
            path: path,
            fileManager: fileManager,
            homeDirectory: fileManager.homeDirectoryForCurrentUser,
            issues: &ignored
        )
    }

    private static func probeIssues(options: Options, settings: SweepSettings) -> [AccessIssue] {
        PermissionGuide.probeProtectedFolders(
            homeDirectory: options.homeDirectory,
            fileManager: options.fileManager,
            relativePaths: PermissionGuide.probePaths(for: settings)
        )
    }

    /// Thorough mode only: children whose names contain the bundle ID.
    private static func relatedCandidates(
        bundleID: String,
        options: Options,
        settings: SweepSettings,
        issues: inout [AccessIssue]
    ) -> [ResidueCandidate] {
        guard settings.safetyLevel == .thorough else { return [] }
        let bid = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard bid.contains("."), bid.count >= 8, !ResidueRules.isBlockedBundleID(bid) else { return [] }
        let needle = bid.lowercased()
        let roots: [(String, ResidueCategory)] = [
            ("Preferences", .preferences),
            ("Preferences/ByHost", .preferences),
            ("LaunchAgents", .launchAgents),
            ("Application Support", .applicationSupport),
            ("Caches", .caches),
            ("Logs", .logs),
            ("WebKit", .webKit),
            ("HTTPStorages", .httpStorages),
            ("Containers", .containers),
            ("Group Containers", .groupContainers),
        ]
        var out: [ResidueCandidate] = []
        let library = options.homeDirectory.appendingPathComponent("Library", isDirectory: true)
        for (relative, category) in roots where settings.allows(category: category) {
            let dir = library.appendingPathComponent(relative, isDirectory: true)
            var isDir: ObjCBool = false
            guard options.fileManager.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            let names: [String]
            do {
                names = try options.fileManager.contentsOfDirectory(atPath: dir.path)
            } catch {
                if let issue = PermissionGuide.issue(path: dir.path, error: error, homeDirectory: options.homeDirectory) {
                    issues.append(issue)
                }
                continue
            }
            for name in names where name.lowercased().contains(needle) {
                let full = (dir.appendingPathComponent(name).path as NSString).standardizingPath
                out.append(ResidueCandidate(path: full, category: category, matchedBy: "related"))
            }
        }
        return out
    }

    private final class IssueBox {
        var issues: [AccessIssue] = []
    }

    private static func measure(
        path: String,
        fileManager: FileManager,
        homeDirectory: URL,
        issues: inout [AccessIssue]
    ) -> UInt64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let n = attrs[.size] as? NSNumber {
                return n.uint64Value
            }
            return 0
        }

        let box = IssueBox()
        let home = homeDirectory
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [],
            errorHandler: { url, error in
                if let issue = PermissionGuide.issue(path: url.path, error: error, homeDirectory: home) {
                    box.issues.append(issue)
                }
                return true
            }
        ) else {
            if let issue = PermissionGuide.probeDirectory(path, fileManager: fileManager, homeDirectory: homeDirectory) {
                issues.append(issue)
            }
            return 0
        }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey])
                if values.isSymbolicLink == true { continue }
                if values.isRegularFile == true {
                    total &+= UInt64(values.fileSize ?? 0)
                }
            } catch {
                if let issue = PermissionGuide.issue(path: fileURL.path, error: error, homeDirectory: home) {
                    box.issues.append(issue)
                }
                continue
            }
        }
        issues.append(contentsOf: box.issues)
        return total
    }
}
