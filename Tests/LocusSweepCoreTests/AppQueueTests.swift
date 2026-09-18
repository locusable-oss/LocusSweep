import XCTest
@testable import LocusSweepCore

final class AppQueueTests: XCTestCase {
    private func info(_ name: String, id: String) -> AppBundleInfo {
        AppBundleInfo(name: name, bundleIdentifier: id, path: "/Applications/\(name).app")
    }

    func testEnqueueDedupesAndPreservesOrder() {
        let a = info("Demo", id: "studio.example.Demo")
        let b = info("Other", id: "studio.example.Other")
        let queue = AppQueue.enqueue([a, b, a], into: [])
        XCTAssertEqual(queue.map(\.info.name), ["Demo", "Other"])
        XCTAssertEqual(queue.map(\.phase), [.pending, .pending])
    }

    func testScanIsStrictlyOneAtATime() {
        let a = info("Demo", id: "studio.example.Demo")
        let b = info("Other", id: "studio.example.Other")
        var queue = AppQueue.enqueue([a, b], into: [])
        XCTAssertEqual(AppQueue.nextToScan(queue)?.info.bundleIdentifier, a.bundleIdentifier)
        XCTAssertEqual(AppQueue.busyCount(queue), 0)

        queue = AppQueue.update(queue[0].id, in: queue) { $0.phase = .scanning }
        XCTAssertNil(AppQueue.nextToScan(queue))
        XCTAssertEqual(AppQueue.cleanOrder(queue), [])
        XCTAssertEqual(AppQueue.busyCount(queue), 1)

        queue = AppQueue.update(queue[0].id, in: queue) { $0.phase = .ready }
        XCTAssertEqual(AppQueue.nextToScan(queue)?.info.bundleIdentifier, b.bundleIdentifier)
    }

    func testCleanOrderSkipsUnreadyAndBusy() {
        let a = info("Demo", id: "studio.example.Demo")
        let b = info("Other", id: "studio.example.Other")
        var queue = AppQueue.enqueue([a, b], into: [])
        let item = ScannedResidue(
            path: "/Users/demo/Library/Caches/studio.example.Demo",
            category: .caches,
            matchedBy: "bundleID",
            byteSize: 10
        )
        queue = AppQueue.update(queue[0].id, in: queue) {
            $0.phase = .ready
            $0.items = [item]
            $0.checkedPaths = [item.path]
        }
        queue = AppQueue.update(queue[1].id, in: queue) { $0.phase = .ready }
        XCTAssertEqual(AppQueue.cleanOrder(queue), [queue[0].id])

        queue = AppQueue.update(queue[0].id, in: queue) { $0.phase = .cleaning }
        XCTAssertTrue(AppQueue.cleanOrder(queue).isEmpty)
        XCTAssertNil(AppQueue.nextToScan(queue))
    }
}
