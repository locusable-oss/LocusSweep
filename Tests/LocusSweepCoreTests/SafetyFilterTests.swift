import XCTest
@testable import LocusSweepCore

final class SafetyFilterTests: XCTestCase {
    func testAllowsUserLibraryResidue() {
        let home = URL(fileURLWithPath: "/Users/demo")
        let path = "/Users/demo/Library/Preferences/studio.example.Demo.plist"
        XCTAssertTrue(SafetyFilter.isSafeToPropose(path: path, homeDirectory: home))
    }

    func testBlocksApplePreferenceDomain() {
        let home = URL(fileURLWithPath: "/Users/demo")
        XCTAssertFalse(SafetyFilter.isSafeToPropose(
            path: "/Users/demo/Library/Preferences/com.apple.finder.plist",
            homeDirectory: home
        ))
        XCTAssertFalse(SafetyFilter.isSafeToPropose(
            path: "/Users/demo/Library/Containers/com.apple.Safari",
            homeDirectory: home
        ))
    }

    func testBlocksSystemPrefixes() {
        let home = URL(fileURLWithPath: "/Users/demo")
        XCTAssertFalse(SafetyFilter.isSafeToPropose(path: "/System/Library/CoreServices", homeDirectory: home))
        XCTAssertFalse(SafetyFilter.isSafeToPropose(path: "/Library/Apple/System", homeDirectory: home))
        XCTAssertFalse(SafetyFilter.isSafeToPropose(path: "/usr/bin/true", homeDirectory: home))
        XCTAssertFalse(SafetyFilter.isSafeToPropose(path: "/Library/Preferences/com.example.x.plist", homeDirectory: home))
    }

    func testBlocksFinderApp() {
        let home = URL(fileURLWithPath: "/Users/demo")
        XCTAssertFalse(SafetyFilter.isSafeToPropose(path: "/System/Applications/Finder.app", homeDirectory: home))
        XCTAssertFalse(SafetyFilter.isSafeToPropose(path: "/Applications/Safari.app", homeDirectory: home))
    }

    func testAllowsThirdPartyAppInApplications() {
        let home = URL(fileURLWithPath: "/Users/demo")
        XCTAssertTrue(SafetyFilter.isSafeToPropose(path: "/Applications/Demo.app", homeDirectory: home))
        XCTAssertTrue(SafetyFilter.isSafeToPropose(path: "/Users/demo/Applications/Demo.app", homeDirectory: home))
    }

    func testRejectsAppBundlesOutsideHomeAndApplications() {
        let home = URL(fileURLWithPath: "/Users/demo")
        XCTAssertFalse(SafetyFilter.isSafeToPropose(path: "/opt/Demo.app", homeDirectory: home))
        XCTAssertFalse(SafetyFilter.isSafeToPropose(path: "/tmp/Demo.app", homeDirectory: home))
        XCTAssertFalse(SafetyFilter.isSafeToPropose(path: "/Applications/Utilities/Demo.app", homeDirectory: home))
        XCTAssertTrue(SafetyFilter.isSafeToPropose(path: "/Users/demo/Downloads/Demo.app", homeDirectory: home))
    }

    func testFilterDropsUnsafeCandidates() {
        let home = URL(fileURLWithPath: "/Users/demo")
        let cands = [
            ResidueCandidate(path: "/Users/demo/Library/Caches/studio.example.Demo", category: .caches, matchedBy: "bundleID"),
            ResidueCandidate(path: "/Users/demo/Library/Preferences/com.apple.Safari.plist", category: .preferences, matchedBy: "bundleID"),
            ResidueCandidate(path: "/System/Library/Foo", category: .caches, matchedBy: "bundleID"),
        ]
        let filtered = SafetyFilter.filter(cands, homeDirectory: home)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.path, cands[0].path)
    }
}
