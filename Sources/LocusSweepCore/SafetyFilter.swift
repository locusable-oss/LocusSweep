import Foundation

/// Conservative path safety checks — skip Apple/system locations by default.
public enum SafetyFilter {
    /// Absolute path prefixes that must never be proposed for deletion (beyond ~/Library residues).
    public static let blockedAbsolutePrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/private/var/db",
        "/private/etc",
        "/Library/Apple",
        "/Library/OSAnalytics",
        "/Library/Updates",
        "/Library/Frameworks",
        "/Library/Extensions",
        "/Library/SystemExtensions",
        "/Applications/Utilities",
    ]

    /// Path component prefixes / names that look like Apple or system domains.
    public static let blockedNamePrefixes: [String] = [
        "com.apple.",
        "com.apple",
        ".globalpreferences",
        "apple.",
        "system.",
    ]

    /// Returns false for paths that should never be offered for trash (conservative default).
    public static func isSafeToPropose(
        path: String,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        matchedBy: String? = nil,
        safetyLevel: SafetyLevel = .balanced
    ) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let standardized = (trimmed as NSString).standardizingPath
        let home = homeDirectory.path
        let homeLibrary = homeDirectory.appendingPathComponent("Library", isDirectory: true).path
        let homeApps = homeDirectory.appendingPathComponent("Applications", isDirectory: true).path

        // Never touch root / empty
        if standardized == "/" || standardized.isEmpty { return false }

        // Block known system absolute prefixes
        for prefix in blockedAbsolutePrefixes {
            if standardized == prefix || standardized.hasPrefix(prefix + "/") {
                return false
            }
        }

        // Block anything under /Library that is not the user's Library
        if standardized == "/Library" || standardized.hasPrefix("/Library/") {
            return false
        }

        // Residues must stay under ~/Library (or a selected .app bundle handled below)
        let underHomeLibrary = standardized == homeLibrary || standardized.hasPrefix(homeLibrary + "/")
        let underHomeApps = standardized == homeApps || standardized.hasPrefix(homeApps + "/")
        let isAppBundle = standardized.lowercased().hasSuffix(".app")

        if underHomeLibrary {
            let parts = standardized.split(separator: "/").map { $0.lowercased() }
            for part in parts {
                for blocked in blockedNamePrefixes {
                    let prefix = blocked.lowercased()
                    if part == prefix || part.hasPrefix(prefix) {
                        return false
                    }
                }
            }
            if safetyLevel == .strict, matchedBy == "appName" {
                return false
            }
            return true
        }

        // A selected .app is allowed only under the home folder or /Applications.
        // /Applications/Utilities is already in blockedAbsolutePrefixes. Anywhere else is unsafe.
        if isAppBundle {
            let leaf = (standardized as NSString).lastPathComponent.lowercased()
            if leaf == "finder.app" || leaf == "safari.app" || leaf == "mail.app"
                || leaf == "system settings.app" || leaf == "system preferences.app" {
                return false
            }
            let underHome = standardized == home || standardized.hasPrefix(home + "/")
            if underHome || underHomeApps || standardized.hasPrefix("/Applications/") {
                return true
            }
            return false
        }

        // Anything else outside ~/Library is unsafe by default
        return false
    }

    /// Filter candidates, dropping unsafe paths.
    public static func filter(
        _ candidates: [ResidueCandidate],
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        safetyLevel: SafetyLevel = .balanced
    ) -> [ResidueCandidate] {
        candidates.filter {
            isSafeToPropose(
                path: $0.path,
                homeDirectory: homeDirectory,
                matchedBy: $0.matchedBy,
                safetyLevel: safetyLevel
            )
        }
    }

}
