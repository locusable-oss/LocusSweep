import Foundation
import AppKit

/// Moves paths into the user’s Trash via FileManager / NSWorkspace — never `rm`.
enum TrashMover {
    struct TrashFailure: Equatable, Hashable {
        var path: String
        var message: String
        var permissionDenied: Bool
    }

    struct Result: Equatable {
        var moved: [String]
        var failed: [TrashFailure]
        var freedBytes: UInt64

        var summary: ResidueSummary {
            ResidueSummary(itemCount: moved.count, totalBytes: freedBytes)
        }
    }

    /// Trash each URL with `FileManager.trashItem`. Falls back to `NSWorkspace.recycle` if needed.
    @MainActor
    static func moveToTrash(paths: [String], byteSizes: [String: UInt64] = [:]) -> Result {
        var moved: [String] = []
        var failed: [TrashFailure] = []
        var freed: UInt64 = 0
        let fm = FileManager.default

        for path in paths {
            let url = URL(fileURLWithPath: path)
            guard fm.fileExists(atPath: path) else {
                failed.append(TrashFailure(path: path, message: "Item no longer exists", permissionDenied: false))
                continue
            }
            guard SafetyFilter.isSafeToPropose(path: path) else {
                failed.append(TrashFailure(path: path, message: "Blocked by safety filter", permissionDenied: false))
                continue
            }
            do {
                var resulting: NSURL?
                try fm.trashItem(at: url, resultingItemURL: &resulting)
                moved.append(path)
                freed &+= byteSizes[path] ?? 0
            } catch {
                let firstDenied = PermissionGuide.isPermissionError(error)
                let group = DispatchGroup()
                var recycleError: Error?
                group.enter()
                NSWorkspace.shared.recycle([url]) { _, err in
                    recycleError = err
                    group.leave()
                }
                _ = group.wait(timeout: .now() + 30)
                if let recycleError {
                    let denied = firstDenied || PermissionGuide.isPermissionError(recycleError)
                    failed.append(TrashFailure(
                        path: path,
                        message: recycleError.localizedDescription,
                        permissionDenied: denied
                    ))
                } else if fm.fileExists(atPath: path) {
                    failed.append(TrashFailure(
                        path: path,
                        message: error.localizedDescription,
                        permissionDenied: firstDenied
                    ))
                } else {
                    moved.append(path)
                    freed &+= byteSizes[path] ?? 0
                }
            }
        }

        return Result(moved: moved, failed: failed, freedBytes: freed)
    }
}
