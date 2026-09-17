import XCTest
@testable import LocusSweepCore

final class ResidueScannerTests: XCTestCase {
    func testScanFindsExistingAndSizes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LocusSweepScan-\(UUID().uuidString)")
        let library = root.appendingPathComponent("Library", isDirectory: true)
        let prefs = library.appendingPathComponent("Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: prefs, withIntermediateDirectories: true)

        let plist = prefs.appendingPathComponent("studio.example.Demo.plist")
        let payload = Data(repeating: 0x41, count: 2048)
        try payload.write(to: plist)

        let support = library.appendingPathComponent("Application Support/studio.example.Demo", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try Data(repeating: 0x42, count: 4096).write(to: support.appendingPathComponent("data.bin"))

        // Missing path should be skipped
        let missing = ResidueCandidate(
            path: library.appendingPathComponent("Caches/studio.example.Demo").path,
            category: .caches,
            matchedBy: "bundleID"
        )
        let existingPrefs = ResidueCandidate(
            path: plist.path,
            category: .preferences,
            matchedBy: "bundleID"
        )
        let existingSupport = ResidueCandidate(
            path: support.path,
            category: .applicationSupport,
            matchedBy: "bundleID"
        )

        let scanned = ResidueScanner.scan(
            candidates: [missing, existingPrefs, existingSupport],
            options: .init(homeDirectory: root)
        )

        XCTAssertEqual(scanned.count, 2)
        let total = ResidueSummary.aggregating(scanned)
        XCTAssertEqual(total.itemCount, 2)
        XCTAssertEqual(total.totalBytes, 2048 + 4096)
        XCTAssertTrue(scanned.contains { $0.path == plist.path && $0.byteSize == 2048 })
        XCTAssertTrue(scanned.contains { $0.path == support.path && $0.byteSize == 4096 })

        try? FileManager.default.removeItem(at: root)
    }

    func testScanForInfoIncludesAppWhenPresent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("LocusSweepApp-\(UUID().uuidString)")
        let app = root.appendingPathComponent("Demo.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: app.appendingPathComponent("Contents/Info.plist"))

        let library = root.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 100).write(to: library.appendingPathComponent("studio.example.Demo.plist"))

        let info = AppBundleInfo(name: "Demo", bundleIdentifier: "studio.example.Demo", path: app.path)
        let scanned = ResidueScanner.scan(
            for: info,
            includeAppBundle: true,
            options: .init(homeDirectory: root)
        )

        XCTAssertTrue(scanned.contains { $0.category == .application && $0.path == app.path })
        XCTAssertTrue(scanned.contains { $0.category == .preferences })

        try? FileManager.default.removeItem(at: root)
    }

    func testByteFormat() {
        XCTAssertEqual(ByteFormat.string(500), "500 B")
        XCTAssertEqual(ByteFormat.string(2048), "2 KB")
        XCTAssertFalse(ByteFormat.string(5_000_000).isEmpty)
    }
}
