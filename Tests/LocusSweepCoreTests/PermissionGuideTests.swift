import XCTest
@testable import LocusSweepCore

final class PermissionGuideTests: XCTestCase {
    func testPermissionErrorCodes() {
        let cocoa = NSError(domain: NSCocoaErrorDomain, code: 257, userInfo: nil)
        let posix = NSError(domain: NSPOSIXErrorDomain, code: 13, userInfo: nil)
        let missing = NSError(domain: NSCocoaErrorDomain, code: 260, userInfo: nil)
        XCTAssertTrue(PermissionGuide.isPermissionError(cocoa))
        XCTAssertTrue(PermissionGuide.isPermissionError(posix))
        XCTAssertFalse(PermissionGuide.isPermissionError(missing))

        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 260, userInfo: [NSUnderlyingErrorKey: posix])
        XCTAssertTrue(PermissionGuide.isPermissionError(wrapped))
    }

    func testProtectedPathClassifiesAsFullDiskAccess() {
        let home = URL(fileURLWithPath: "/Users/demo")
        let error = NSError(domain: NSPOSIXErrorDomain, code: 1, userInfo: nil)
        let issue = PermissionGuide.issue(
            path: "/Users/demo/Library/Containers",
            error: error,
            homeDirectory: home
        )
        XCTAssertEqual(issue?.kind, .fullDiskAccess)
        XCTAssertFalse(PermissionGuide.steps(for: .fullDiskAccess).isEmpty)
        XCTAssertFalse(PermissionGuide.settingsURLs(for: .fullDiskAccess).isEmpty)
        XCTAssertTrue(PermissionGuide.summary(issues: [issue!]).contains("Full Disk Access"))
        let docs = PermissionGuide.issue(
            path: "/Users/demo/Documents/Demo",
            error: error,
            homeDirectory: home
        )
        XCTAssertEqual(docs?.kind, .filesAndFolders)
        XCTAssertFalse(PermissionGuide.settingsURLs(for: .filesAndFolders).isEmpty)
    }

    func testMissingDirectoryIsNotAnIssue() {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("LocusSweepMiss-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let missing = home.appendingPathComponent("Library/Containers").path
        XCTAssertNil(PermissionGuide.probeDirectory(missing, homeDirectory: home))
        XCTAssertTrue(PermissionGuide.probeProtectedFolders(homeDirectory: home).isEmpty)
    }

    func testUnreadableProtectedDirectoryIsRecoverable() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("LocusSweepPerm-\(UUID().uuidString)")
        let containers = home.appendingPathComponent("Library/Containers", isDirectory: true)
        try FileManager.default.createDirectory(at: containers, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: containers.path)
            try? FileManager.default.removeItem(at: home)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: containers.path)

        let issue = PermissionGuide.probeDirectory(containers.path, homeDirectory: home)
        XCTAssertEqual(issue?.kind, .fullDiskAccess)
        XCTAssertTrue(issue?.message.contains("Full Disk Access") == true)

        let probed = PermissionGuide.probeProtectedFolders(
            homeDirectory: home,
            relativePaths: ["Library/Containers"]
        )
        XCTAssertEqual(probed.count, 1)
    }

    func testNormalizesDuplicateIssues() {
        let home = URL(fileURLWithPath: "/Users/demo")
        let error = NSError(domain: NSCocoaErrorDomain, code: 257)
        let a = PermissionGuide.issue(path: "/Users/demo/Library/Mail", error: error, homeDirectory: home)!
        let b = PermissionGuide.issue(path: "/tmp/notes", error: error, homeDirectory: home)!
        let list = PermissionGuide.normalized([b, a, a])
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.first?.kind, .fullDiskAccess)
    }
}
