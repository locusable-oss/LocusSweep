import Foundation

/// Why a folder could not be read. Every kind here is recoverable: grant access, then scan again.
public enum AccessKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case fullDiskAccess
    case filesAndFolders
    case unreadable
}

public struct AccessIssue: Equatable, Hashable, Sendable, Identifiable, Codable {
    public var path: String
    public var kind: AccessKind
    public var message: String

    public var id: String { "\(kind.rawValue)|\(path)" }

    public init(path: String, kind: AccessKind, message: String) {
        self.path = path
        self.kind = kind
        self.message = message
    }
}

/// Classifies permission failures and the steps that recover from them.
public enum PermissionGuide {
    public static let fullDiskAccessURLString =
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles"
    public static let fullDiskAccessLegacyURLString =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    public static let filesAndFoldersURLString =
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_FilesAndFolders"

    /// Relative to the user home. Listing these usually needs Full Disk Access.
    public static let protectedRelativePaths: [String] = [
        "Library/Containers",
        "Library/Group Containers",
        "Library/Mail",
        "Library/Messages",
        "Library/Safari",
        "Library/Cookies",
        "Library/Accounts",
        "Library/IdentityServices",
        "Library/HomeKit",
        "Library/Application Support/AddressBook",
        "Library/Application Support/CallHistoryDB",
        "Library/Application Support/com.apple.TCC",
    ]

    public static func settingsURLs(for kind: AccessKind) -> [URL] {
        let strings: [String]
        switch kind {
        case .fullDiskAccess:
            strings = [fullDiskAccessURLString, fullDiskAccessLegacyURLString]
        case .filesAndFolders:
            strings = [filesAndFoldersURLString, fullDiskAccessURLString, fullDiskAccessLegacyURLString]
        case .unreadable:
            strings = [fullDiskAccessURLString, fullDiskAccessLegacyURLString, filesAndFoldersURLString]
        }
        return strings.compactMap { URL(string: $0) }
    }

    public static func title(for kind: AccessKind) -> String {
        switch kind {
        case .fullDiskAccess: return "Full Disk Access needed"
        case .filesAndFolders: return "Folder access needed"
        case .unreadable: return "Some folders could not be read"
        }
    }

    public static func steps(for kind: AccessKind) -> [String] {
        switch kind {
        case .fullDiskAccess:
            return [
                "Choose Open System Settings.",
                "Go to Privacy & Security → Full Disk Access and turn LocusSweep on. Unlock the padlock if macOS asks.",
                "Return here and choose Scan Again. Nothing was deleted; this only retries unread folders.",
            ]
        case .filesAndFolders:
            return [
                "Choose Open System Settings.",
                "Go to Privacy & Security → Files and Folders and allow LocusSweep, or grant Full Disk Access.",
                "Return here and choose Scan Again. Moves still go to Trash only.",
            ]
        case .unreadable:
            return [
                "Choose Open System Settings and grant Full Disk Access, or fix the folder’s permissions in Finder.",
                "Return here and choose Scan Again. You can keep using items that were readable.",
            ]
        }
    }

    public static func summary(issues: [AccessIssue]) -> String {
        let list = normalized(issues)
        guard let first = list.first else {
            return "Grant access, then scan again. LocusSweep does not delete anything while retrying."
        }
        let noun = list.count == 1 ? "1 protected folder" : "\(list.count) protected folders"
        switch first.kind {
        case .fullDiskAccess:
            return "macOS hid \(noun), so leftovers there were not scanned. Grant Full Disk Access and scan again. This does not delete anything."
        case .filesAndFolders:
            return "macOS blocked \(noun). Allow access and scan again. Items already in Trash stay there."
        case .unreadable:
            return "\(noun) could not be read. Grant access if macOS blocked them, then scan again."
        }
    }

    /// Cocoa 257/513 and POSIX EPERM/EACCES, including an underlying error. Not-found is not a permission failure.
    public static func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain && (ns.code == 257 || ns.code == 513) {
            return true
        }
        if ns.domain == NSPOSIXErrorDomain && (ns.code == 1 || ns.code == 13) {
            return true
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            return isPermissionError(underlying)
        }
        return false
    }

    public static func isProtectedLibraryPath(_ path: String, homeDirectory: URL) -> Bool {
        let standardized = (path as NSString).standardizingPath
        let home = (homeDirectory.path as NSString).standardizingPath
        for relative in protectedRelativePaths {
            let full = (home as NSString).appendingPathComponent(relative)
            if standardized == full || standardized.hasPrefix(full + "/") {
                return true
            }
        }
        return false
    }

    public static func issue(path: String, error: Error, homeDirectory: URL) -> AccessIssue? {
        guard isPermissionError(error) else { return nil }
        let protected = isProtectedLibraryPath(path, homeDirectory: homeDirectory)
        let kind: AccessKind = protected ? .fullDiskAccess : .unreadable
        let message: String
        switch kind {
        case .fullDiskAccess:
            message = "Cannot read \(path). macOS is hiding this folder until LocusSweep has Full Disk Access."
        case .filesAndFolders:
            message = "Cannot read \(path). Allow access in Privacy & Security, then scan again."
        case .unreadable:
            message = "Cannot read \(path). Grant access if macOS blocked it, then scan again."
        }
        return AccessIssue(path: path, kind: kind, message: message)
    }

    /// Missing paths are nil. A directory that exists but cannot be listed becomes an issue.
    public static func probeDirectory(
        _ path: String,
        fileManager: FileManager = .default,
        homeDirectory: URL
    ) -> AccessIssue? {
        var isDir: ObjCBool = false
        if !fileManager.fileExists(atPath: path, isDirectory: &isDir) {
            do {
                _ = try fileManager.attributesOfItem(atPath: path)
            } catch {
                return issue(path: path, error: error, homeDirectory: homeDirectory)
            }
            return nil
        }
        guard isDir.boolValue else { return nil }
        do {
            _ = try fileManager.contentsOfDirectory(atPath: path)
            return nil
        } catch {
            return issue(path: path, error: error, homeDirectory: homeDirectory)
        }
    }

    public static func probeProtectedFolders(
        homeDirectory: URL,
        fileManager: FileManager = .default,
        relativePaths: [String]? = nil
    ) -> [AccessIssue] {
        let relative = relativePaths ?? protectedRelativePaths
        var found: [AccessIssue] = []
        for item in relative {
            let path = homeDirectory.appendingPathComponent(item).path
            if let issue = probeDirectory(path, fileManager: fileManager, homeDirectory: homeDirectory) {
                found.append(issue)
            }
        }
        return normalized(found)
    }

    /// Full Disk Access issues first, then stable path order. One row per path.
    public static func normalized(_ issues: [AccessIssue]) -> [AccessIssue] {
        var seen = Set<String>()
        let sorted = issues.sorted { lhs, rhs in
            let lr = rank(lhs.kind)
            let rr = rank(rhs.kind)
            if lr != rr { return lr < rr }
            return lhs.path < rhs.path
        }
        return sorted.filter { seen.insert($0.id).inserted }
    }

    /// Protected roots worth probing for the categories the user actually scans.
    public static func probePaths(for settings: SweepSettings) -> [String] {
        var relative: [String] = []
        if settings.allows(category: .containers) {
            relative.append("Library/Containers")
        }
        if settings.allows(category: .groupContainers) {
            relative.append("Library/Group Containers")
        }
        if settings.allows(category: .cookies) {
            relative.append("Library/Cookies")
        }
        if !relative.isEmpty {
            relative.append(contentsOf: [
                "Library/Mail",
                "Library/Messages",
                "Library/Safari",
            ])
        }
        return relative
    }

    private static func rank(_ kind: AccessKind) -> Int {
        switch kind {
        case .fullDiskAccess: return 0
        case .filesAndFolders: return 1
        case .unreadable: return 2
        }
    }
}
