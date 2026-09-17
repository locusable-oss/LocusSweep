import Foundation
import AppKit

/// Moves paths into the user’s Trash via FileManager / NSWorkspace — never `rm`.
enum TrashMover {
    struct Result: Equatable {
        var moved: [String]
        var failed: [(path: String, message: String)]
        var freedBytes: UInt64

        var summary: ResidueSummary {
            ResidueSummary(itemCount: moved.count, totalBytes: freedBytes)
        }
    }

    /// Trash each URL with `FileManager.trashItem`. Falls back to `NSWorkspace.recycle` if needed.
    @MainActor
    static func moveToTrash(paths: [String], byteSizes: [String: UInt64] = [:]) -> Result {
        var moved: [String] = []
        var failed: [(path: String, message: String)] = []
        var freed: UInt64 = 0
        let fm = FileManager.default

        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path) else {
                failed.append((path, "Item no longer exists"))
                continue
            }
            // Re-check safety immediately before trash
            guard SafetyFilter.isSafeToPropose(path: path) else {
                failed.append((path, "Blocked by safety filter"))
                continue
            }
            do {
                var resulting: NSURL?
                try fm.trashItem(at: url, resultingItemURL: &resulting)
                moved.append(path)
                freed &+= byteSizes[path] ?? 0
            } catch {
                // Fallback: NSWorkspace.recycle (still Trash, not rm)
                let group = DispatchGroup()
                var recycleError: Error?
                group.enter()
                NSWorkspace.shared.recycle([url]) { _, err in
                    recycleError = err
                    group.leave()
                }
                _ = group.wait(timeout: .now() + 30)
                if let recycleError {
                    failed.append((path, recycleError.localizedDescription))
                } else if fm.fileExists(atPath: path) {
                    failed.append((path, error.localizedDescription))
                } else {
                    moved.append(path)
                    freed &+= byteSizes[path] ?? 0
                }
            }
        }

        return Result(moved: moved, failed: failed, freedBytes: freed)
    }
}
