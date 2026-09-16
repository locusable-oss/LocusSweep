import XCTest
@testable import LocusSweepCore

final class AppBundleReaderTests: XCTestCase {
    func testReadsSyntheticBundle() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".app")
        let contents = root.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": "studio.example.Demo",
            "CFBundleName": "Demo",
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "42",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))

        let info = try AppBundleReader.read(url: root)
        XCTAssertEqual(info.bundleIdentifier, "studio.example.Demo")
        XCTAssertEqual(info.name, "Demo")
        XCTAssertEqual(info.shortVersion, "1.2.3")
        XCTAssertTrue(info.path.hasSuffix(".app"))

        try? FileManager.default.removeItem(at: root)
    }

    func testRejectsNonApp() {
        let url = URL(fileURLWithPath: "/tmp/not-an-app.txt")
        XCTAssertThrowsError(try AppBundleReader.read(url: url))
    }
}
