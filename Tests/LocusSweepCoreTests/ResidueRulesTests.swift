import XCTest
@testable import LocusSweepCore

final class ResidueRulesTests: XCTestCase {
    func testCandidatesForThirdPartyApp() {
        let home = URL(fileURLWithPath: "/Users/demo")
        let cands = ResidueRules.candidatePaths(
            bundleID: "studio.example.Demo",
            appName: "Demo",
            homeDirectory: home
        )
        XCTAssertFalse(cands.isEmpty)
        XCTAssertTrue(cands.contains { $0.path.hasSuffix("/Library/Preferences/studio.example.Demo.plist") })
        XCTAssertTrue(cands.contains { $0.path.hasSuffix("/Library/Application Support/studio.example.Demo") })
        XCTAssertTrue(cands.contains { $0.path.hasSuffix("/Library/Caches/Demo") })
        XCTAssertTrue(cands.contains { $0.path.hasSuffix("/Library/Saved Application State/studio.example.Demo.savedState") })
        XCTAssertTrue(cands.contains { $0.path.hasSuffix("/Library/Containers/studio.example.Demo") })
        XCTAssertTrue(cands.contains { $0.path.hasSuffix("/Library/HTTPStorages/studio.example.Demo") })
        XCTAssertFalse(ResidueRules.isBlockedBundleID("studio.example.Demo"))
    }

    func testBlocksAppleBundle() {
        XCTAssertTrue(ResidueRules.isBlockedBundleID("com.apple.finder"))
        XCTAssertTrue(ResidueRules.isBlockedBundleID("com.apple.Safari"))
        let cands = ResidueRules.candidatePaths(
            bundleID: "com.apple.finder",
            appName: "Finder",
            homeDirectory: URL(fileURLWithPath: "/Users/demo")
        )
        XCTAssertTrue(cands.isEmpty)
    }

    func testLibraryRootsCoverCommonCategories() {
        let cats = Set(ResidueRules.libraryRoots.map(\.category))
        XCTAssertTrue(cats.contains(.preferences))
        XCTAssertTrue(cats.contains(.applicationSupport))
        XCTAssertTrue(cats.contains(.caches))
        XCTAssertTrue(cats.contains(.logs))
        XCTAssertTrue(cats.contains(.savedApplicationState))
        XCTAssertTrue(cats.contains(.containers))
        XCTAssertTrue(cats.contains(.httpStorages))
    }
}
