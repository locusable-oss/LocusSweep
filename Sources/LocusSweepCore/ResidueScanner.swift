import Foundation

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
        let safe = SafetyFilter.filter(candidates, homeDirectory: options.homeDirectory)
        var out: [ScannedResidue] = []
        out.reserveCapacity(safe.count)

        for cand in safe {
            var isDir: ObjCBool = false
            guard options.fileManager.fileExists(atPath: cand.path, isDirectory: &isDir) else {
                continue
            }
            let size = byteSize(of: cand.path, fileManager: options.fileManager)
            out.append(ScannedResidue(candidate: cand, byteSize: size))
        }

        return out.sorted { lhs, rhs in
            if lhs.category.displayName != rhs.category.displayName {
                return lhs.category.displayName < rhs.category.displayName
            }
            return lhs.path < rhs.path
        }
    }

    /// Scan from app info: build rule candidates → safety filter → size.
    public static func scan(
        for info: AppBundleInfo,
        includeAppBundle: Bool = true,
        options: Options = Options()
    ) -> [ScannedResidue] {
        var candidates = ResidueRules.candidatePaths(for: info, homeDirectory: options.homeDirectory)
        if includeAppBundle {
            let appCand = ResidueCandidate(
                path: info.path,
                category: .application,
                matchedBy: "appBundle"
            )
            candidates.insert(appCand, at: 0)
        }
        return scan(candidates: candidates, options: options)
    }

    /// Recursive byte size of a file or directory. Symlinks are not followed as directories.
    public static func byteSize(of path: String, fileManager: FileManager = .default) -> UInt64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let n = attrs[.size] as? NSNumber {
                return n.uint64Value
            }
            return 0
        }

        // Directory: enumerate without following directory symlinks
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey],
            options: [],
            errorHandler: { _, _ in true }
        ) else {
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
                continue
            }
        }
        return total
    }
}
