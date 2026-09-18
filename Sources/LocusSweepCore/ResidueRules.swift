import Foundation

/// Categories of common macOS per-user residue under `~/Library`.
public enum ResidueCategory: String, CaseIterable, Sendable, Codable, Hashable {
    case application
    case preferences
    case applicationSupport
    case caches
    case logs
    case savedApplicationState
    case containers
    case groupContainers
    case httpStorages
    case cookies
    case webKit
    case applicationScripts
    case launchAgents

    /// Categories that live under `~/Library` (the app bundle is not one of them).
    public static var libraryCategories: [ResidueCategory] {
        allCases.filter { $0 != .application }
    }

    public var displayName: String {
        switch self {
        case .application: return "Application"
        case .preferences: return "Preferences"
        case .applicationSupport: return "Application Support"
        case .caches: return "Caches"
        case .logs: return "Logs"
        case .savedApplicationState: return "Saved Application State"
        case .containers: return "Containers"
        case .groupContainers: return "Group Containers"
        case .httpStorages: return "HTTPStorages"
        case .cookies: return "Cookies"
        case .webKit: return "WebKit"
        case .applicationScripts: return "Application Scripts"
        case .launchAgents: return "LaunchAgents"
        }
    }
}

public struct ResidueRoot: Equatable, Sendable, Hashable {
    public var category: ResidueCategory
    /// Path relative to `~/Library` (no leading slash).
    public var relativeLibraryPath: String

    public init(category: ResidueCategory, relativeLibraryPath: String) {
        self.category = category
        self.relativeLibraryPath = relativeLibraryPath
    }
}

public struct ResidueCandidate: Equatable, Sendable, Identifiable, Hashable {
    public var id: String { path }
    public var path: String
    public var category: ResidueCategory
    public var matchedBy: String

    public init(path: String, category: ResidueCategory, matchedBy: String) {
        self.path = path
        self.category = category
        self.matchedBy = matchedBy
    }
}

/// Safe-default residue path rules for a Bundle ID / app name under the user Library.
public enum ResidueRules {
    /// Common macOS residue roots under `~/Library`.
    public static let libraryRoots: [ResidueRoot] = [
        .init(category: .preferences, relativeLibraryPath: "Preferences"),
        .init(category: .applicationSupport, relativeLibraryPath: "Application Support"),
        .init(category: .caches, relativeLibraryPath: "Caches"),
        .init(category: .logs, relativeLibraryPath: "Logs"),
        .init(category: .savedApplicationState, relativeLibraryPath: "Saved Application State"),
        .init(category: .containers, relativeLibraryPath: "Containers"),
        .init(category: .groupContainers, relativeLibraryPath: "Group Containers"),
        .init(category: .httpStorages, relativeLibraryPath: "HTTPStorages"),
        .init(category: .cookies, relativeLibraryPath: "Cookies"),
        .init(category: .webKit, relativeLibraryPath: "WebKit"),
        .init(category: .applicationScripts, relativeLibraryPath: "Application Scripts"),
        .init(category: .launchAgents, relativeLibraryPath: "LaunchAgents"),
    ]

    /// Bundle-ID prefixes that must never be proposed as residue (Apple / system).
    public static let blockedBundlePrefixes: [String] = [
        "com.apple.",
        "com.apple",
        "apple.",
        "system.",
        "edu.mit.Kerberos",
    ]

    public static func isBlockedBundleID(_ bundleID: String) -> Bool {
        let id = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if id.isEmpty { return true }
        for prefix in blockedBundlePrefixes {
            let blocked = prefix.lowercased()
            if id == blocked || id.hasPrefix(blocked) { return true }
        }
        return false
    }

    /// Build candidate residue paths for an app. Does not touch the filesystem (listing / size is later).
    public static func candidatePaths(
        bundleID: String,
        appName: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        settings: SweepSettings = .default
    ) -> [ResidueCandidate] {
        let bid = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isBlockedBundleID(bid) else { return [] }

        let library = homeDirectory.appendingPathComponent("Library", isDirectory: true)
        var out: [ResidueCandidate] = []
        var seen = Set<String>()

        func add(_ relativeUnderLibrary: String, category: ResidueCategory, matchedBy: String) {
            let url = library.appendingPathComponent(relativeUnderLibrary)
            let path = url.path
            // Skip anything that would resolve outside ~/Library (path tricks)
            let libPath = library.path
            guard path == libPath || path.hasPrefix(libPath + "/") else { return }
            // Skip obvious system preference domains even if somehow passed
            if category == .preferences {
                let leaf = (relativeUnderLibrary as NSString).lastPathComponent.lowercased()
                if leaf.hasPrefix("com.apple.") || leaf == ".globalpreferences.plist" { return }
            }
            if seen.insert(path).inserted {
                out.append(ResidueCandidate(path: path, category: category, matchedBy: matchedBy))
            }
        }

        for root in libraryRoots where settings.allows(category: root.category) {
            let base = root.relativeLibraryPath

            switch root.category {
            case .application:
                break // app bundle path is injected by ResidueScanner, not library roots
            case .preferences:
                if !bid.isEmpty {
                    add("\(base)/\(bid).plist", category: .preferences, matchedBy: "bundleID")
                }
            case .savedApplicationState:
                if !bid.isEmpty {
                    add("\(base)/\(bid).savedState", category: .savedApplicationState, matchedBy: "bundleID")
                }
            case .containers, .applicationScripts:
                if !bid.isEmpty {
                    add("\(base)/\(bid)", category: root.category, matchedBy: "bundleID")
                }
            case .groupContainers:
                // Group container folder names are usually the group id; bundle id is a safe hint only.
                if !bid.isEmpty {
                    add("\(base)/\(bid)", category: .groupContainers, matchedBy: "bundleID")
                }
            case .httpStorages:
                if !bid.isEmpty {
                    add("\(base)/\(bid)", category: .httpStorages, matchedBy: "bundleID")
                }
            case .cookies:
                if !bid.isEmpty {
                    add("\(base)/\(bid).binarycookies", category: .cookies, matchedBy: "bundleID")
                }
            case .launchAgents:
                if !bid.isEmpty {
                    add("\(base)/\(bid).plist", category: .launchAgents, matchedBy: "bundleID")
                }
            case .applicationSupport, .caches, .logs, .webKit:
                if !bid.isEmpty {
                    add("\(base)/\(bid)", category: root.category, matchedBy: "bundleID")
                }
                // App display name is a common folder under Support / Caches / Logs.
                // Strict safety keeps bundle-ID paths only.
                if settings.safetyLevel != .strict, !name.isEmpty, name != bid {
                    add("\(base)/\(name)", category: root.category, matchedBy: "appName")
                }
            }
        }

        return out.sorted { lhs, rhs in
            if lhs.category.displayName != rhs.category.displayName {
                return lhs.category.displayName < rhs.category.displayName
            }
            return lhs.path < rhs.path
        }
    }

    /// Convenience from `AppBundleInfo`.
    public static func candidatePaths(
        for info: AppBundleInfo,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        settings: SweepSettings = .default
    ) -> [ResidueCandidate] {
        candidatePaths(
            bundleID: info.bundleIdentifier,
            appName: info.name,
            homeDirectory: homeDirectory,
            settings: settings
        )
    }
}
