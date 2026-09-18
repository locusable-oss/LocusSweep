import XCTest
@testable import LocusSweepCore

final class SweepSettingsTests: XCTestCase {
    func testDefaultMatchesPreviousScope() {
        let home = URL(fileURLWithPath: "/Users/demo")
        let baseline = ResidueRules.candidatePaths(
            bundleID: "studio.example.Demo",
            appName: "Demo",
            homeDirectory: home
        )
        let explicit = ResidueRules.candidatePaths(
            bundleID: "studio.example.Demo",
            appName: "Demo",
            homeDirectory: home,
            settings: .default
        )
        XCTAssertEqual(baseline, explicit)
        XCTAssertTrue(explicit.contains { $0.matchedBy == "appName" })
    }

    func testStrictDropsNameMatches() {
        let home = URL(fileURLWithPath: "/Users/demo")
        let settings = SweepSettings(
            enabledCategories: Set(ResidueCategory.libraryCategories),
            includeAppBundle: false,
            safetyLevel: .strict
        )
        let cands = ResidueRules.candidatePaths(
            bundleID: "studio.example.Demo",
            appName: "Demo",
            homeDirectory: home,
            settings: settings
        )
        XCTAssertFalse(cands.isEmpty)
        XCTAssertFalse(cands.contains { $0.matchedBy == "appName" })
        XCTAssertTrue(cands.allSatisfy { $0.matchedBy == "bundleID" })
        XCTAssertFalse(SafetyFilter.isSafeToPropose(
            path: "/Users/demo/Library/Caches/Demo",
            homeDirectory: home,
            matchedBy: "appName",
            safetyLevel: .strict
        ))
        XCTAssertTrue(SafetyFilter.isSafeToPropose(
            path: "/Users/demo/Library/Caches/Demo",
            homeDirectory: home,
            matchedBy: "appName",
            safetyLevel: .balanced
        ))
    }

    func testDisabledCategoryIsOmitted() {
        let home = URL(fileURLWithPath: "/Users/demo")
        let settings = SweepSettings(
            enabledCategories: [.preferences],
            includeAppBundle: false,
            safetyLevel: .balanced
        )
        let cands = ResidueRules.candidatePaths(
            bundleID: "studio.example.Demo",
            appName: "Demo",
            homeDirectory: home,
            settings: settings
        )
        XCTAssertFalse(cands.isEmpty)
        XCTAssertTrue(cands.allSatisfy { $0.category == .preferences })
    }

    func testPreferencesRoundTrip() {
        let suite = "LocusSweepSettings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var settings = SweepSettings.default
        settings.safetyLevel = .thorough
        settings.includeAppBundle = false
        settings.enabledCategories = [.caches, .logs]
        SweepPreferences.save(settings, userDefaults: defaults)
        let loaded = SweepPreferences.load(userDefaults: defaults)
        XCTAssertEqual(loaded, settings)
        SweepPreferences.reset(userDefaults: defaults)
        XCTAssertEqual(SweepPreferences.load(userDefaults: defaults), .default)
    }

    func testThoroughFindsRelatedNames() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("LocusSweepThru-\(UUID().uuidString)")
        let prefs = home.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: prefs, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let exact = prefs.appendingPathComponent("studio.example.Demo.plist")
        let related = prefs.appendingPathComponent("helper.studio.example.Demo.plist")
        try Data(repeating: 1, count: 10).write(to: exact)
        try Data(repeating: 2, count: 20).write(to: related)

        let info = AppBundleInfo(name: "Demo", bundleIdentifier: "studio.example.Demo", path: "/Applications/Demo.app")
        let balanced = ResidueScanner.scanReport(
            for: info,
            includeAppBundle: false,
            options: .init(homeDirectory: home),
            settings: SweepSettings(enabledCategories: [.preferences], includeAppBundle: false, safetyLevel: .balanced)
        )
        XCTAssertTrue(balanced.items.contains { $0.path == exact.path })
        XCTAssertFalse(balanced.items.contains { $0.path == related.path })

        let thorough = ResidueScanner.scanReport(
            for: info,
            includeAppBundle: false,
            options: .init(homeDirectory: home),
            settings: SweepSettings(enabledCategories: [.preferences], includeAppBundle: false, safetyLevel: .thorough)
        )
        XCTAssertTrue(thorough.items.contains { $0.path == exact.path })
        XCTAssertTrue(thorough.items.contains { $0.path == related.path && $0.matchedBy == "related" })
    }

    func testScanReportSurfacesUnreadableContainers() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("LocusSweepFDA-\(UUID().uuidString)")
        let containers = home.appendingPathComponent("Library/Containers", isDirectory: true)
        try FileManager.default.createDirectory(at: containers, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: containers.path)
            try? FileManager.default.removeItem(at: home)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: containers.path)

        let info = AppBundleInfo(name: "Demo", bundleIdentifier: "studio.example.Demo", path: "/Applications/Demo.app")
        let report = ResidueScanner.scanReport(
            for: info,
            includeAppBundle: false,
            options: .init(homeDirectory: home),
            settings: .default
        )
        XCTAssertTrue(report.accessIssues.contains { $0.kind == .fullDiskAccess && $0.path == containers.path })
    }

    func testBlockedBundleProducesNoAppItem() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("LocusSweepApple-\(UUID().uuidString)")
        let app = home.appendingPathComponent("Safari.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let info = AppBundleInfo(name: "Safari", bundleIdentifier: "com.apple.Safari", path: app.path)
        let report = ResidueScanner.scanReport(for: info, includeAppBundle: true, options: .init(homeDirectory: home))
        XCTAssertTrue(report.items.isEmpty)
    }
}
