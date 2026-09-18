import Foundation

/// How aggressive name matching is. System and Apple paths stay blocked at every level.
public enum SafetyLevel: String, Codable, CaseIterable, Sendable, Equatable, Hashable {
    case strict
    case balanced
    case thorough

    public var title: String {
        switch self {
        case .strict: return "Strict"
        case .balanced: return "Balanced"
        case .thorough: return "Thorough"
        }
    }

    public var detail: String {
        switch self {
        case .strict:
            return "Bundle ID paths only. Skips folders that match only the app name. Apple and system paths stay blocked."
        case .balanced:
            return "Bundle ID paths, plus the app name under Support, Caches, Logs, and WebKit. Recommended. Apple and system paths stay blocked."
        case .thorough:
            return "Balanced matches, plus files whose names contain the bundle ID. Can take longer. Apple and system paths stay blocked."
        }
    }
}

/// Scan scope and safety, persisted by `SweepPreferences`.
public struct SweepSettings: Equatable, Hashable, Codable, Sendable {
    public var enabledCategories: Set<ResidueCategory>
    public var includeAppBundle: Bool
    public var safetyLevel: SafetyLevel

    public init(
        enabledCategories: Set<ResidueCategory>,
        includeAppBundle: Bool,
        safetyLevel: SafetyLevel
    ) {
        self.enabledCategories = enabledCategories
        self.includeAppBundle = includeAppBundle
        self.safetyLevel = safetyLevel
    }

    /// All user-Library categories, include the .app, balanced safety.
    public static let `default` = SweepSettings(
        enabledCategories: Set(ResidueCategory.libraryCategories),
        includeAppBundle: true,
        safetyLevel: .balanced
    )

    public func allows(category: ResidueCategory) -> Bool {
        if category == .application { return includeAppBundle }
        return enabledCategories.contains(category)
    }
}

public enum SweepPreferences {
    public static let defaultsKey = "studio.locusable.LocusSweep.settings"

    public static func load(userDefaults: UserDefaults = .standard) -> SweepSettings {
        guard let data = userDefaults.data(forKey: defaultsKey) else { return .default }
        guard let decoded = try? JSONDecoder().decode(SweepSettings.self, from: data) else { return .default }
        return decoded
    }

    public static func save(_ settings: SweepSettings, userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: defaultsKey)
    }

    public static func reset(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: defaultsKey)
    }
}
