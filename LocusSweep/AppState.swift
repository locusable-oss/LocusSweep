import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum TrashConfirmMode: Equatable {
    case current
    case queue
}

@MainActor
final class AppState: ObservableObject {
    @Published var queue: [QueuedApp] = []
    @Published var activeID: String?
    @Published var settings: SweepSettings
    @Published var isScanning = false
    @Published var isTrashing = false
    @Published var errorMessage: String?
    @Published var isDropTargeted = false
    @Published var showTrashConfirm = false
    @Published var trashConfirmMode: TrashConfirmMode = .current
    @Published var showSummary = false
    @Published var showPermissionGuide = false
    @Published var settingsOpenFailed = false
    @Published var lastSummary: ResidueSummary?
    @Published var lastFailures: [TrashMover.TrashFailure] = []
    @Published var lastCleanedAppCount = 0

    private var scanLoopActive = false
    private var scanTicket = 0

    init(settings: SweepSettings = SweepPreferences.load()) {
        self.settings = settings
    }

    var activeApp: QueuedApp? {
        guard let activeID else { return nil }
        return queue.first { $0.id == activeID }
    }

    var accessIssues: [AccessIssue] {
        PermissionGuide.normalized(queue.flatMap(\.accessIssues))
    }

    var checkedSummary: ResidueSummary {
        ResidueSummary.aggregating(activeApp?.checkedItems ?? [])
    }

    var cleanableCount: Int {
        AppQueue.cleanOrder(queue).count
    }

    var canTrashCurrent: Bool {
        guard !isScanning, !isTrashing, let app = activeApp else { return false }
        return app.phase == .ready && !app.checkedPaths.isEmpty
    }

    var progressLabel: String {
        guard !queue.isEmpty else { return "No apps in the queue" }
        if let index = queue.firstIndex(where: { $0.phase == .scanning }) {
            return "Scanning \(index + 1) of \(queue.count) — \(queue[index].info.name)"
        }
        if let index = queue.firstIndex(where: { $0.phase == .cleaning }) {
            return "Cleaning \(index + 1) of \(queue.count) — \(queue[index].info.name)"
        }
        let finished = queue.filter {
            $0.phase == .ready || $0.phase == .cleaned || $0.phase == .skipped || $0.phase == .failed
        }.count
        return "\(finished) of \(queue.count) finished"
    }

    var confirmTitle: String {
        if trashConfirmMode == .queue {
            let ids = Set(AppQueue.cleanOrder(queue))
            let apps = queue.filter { ids.contains($0.id) }
            let summary = ResidueSummary.aggregating(apps.flatMap(\.checkedItems))
            return "Move \(summary.itemCount) item(s) (\(summary.formattedSize)) from \(apps.count) app(s) to Trash, one app at a time?"
        }
        let name = activeApp?.info.name ?? "this app"
        return "Move \(checkedSummary.itemCount) item(s) (\(checkedSummary.formattedSize)) from \(name) to Trash?"
    }

    func ingest(urls: [URL]) {
        var infos: [AppBundleInfo] = []
        var errors: [String] = []
        for url in urls {
            do {
                infos.append(try AppBundleReader.read(url: url))
            } catch {
                errors.append(error.localizedDescription)
            }
        }
        if errors.isEmpty {
            if !infos.isEmpty { errorMessage = nil }
        } else {
            errorMessage = errors.joined(separator: "\n")
        }
        guard !infos.isEmpty else { return }
        queue = AppQueue.enqueue(infos, into: queue)
        if activeID == nil {
            activeID = queue.first?.id
        }
        ensureScanLoop()
    }

    func ingestProviders(_ providers: [NSItemProvider]) {
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else { return }
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                guard let url = Self.url(fromDropItem: item) else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }
        group.notify(queue: .main) { [weak self] in
            Task { @MainActor in
                self?.ingest(urls: urls)
            }
        }
    }

    func chooseApps() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.message = "Choose one or more .app bundles. They are scanned one at a time."
        panel.prompt = "Add to Queue"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        ingest(urls: panel.urls)
    }

    func clear() {
        scanTicket += 1
        queue = []
        activeID = nil
        errorMessage = nil
        lastSummary = nil
        lastFailures = []
        lastCleanedAppCount = 0
        showSummary = false
        showTrashConfirm = false
        showPermissionGuide = false
        settingsOpenFailed = false
        isScanning = false
        isTrashing = false
    }

    func select(_ id: String) {
        activeID = id
    }

    func selectAll(_ on: Bool) {
        guard let id = activeID else { return }
        queue = AppQueue.update(id, in: queue) { app in
            app.checkedPaths = on ? Set(app.items.map(\.path)) : []
        }
    }

    func setChecked(path: String, on: Bool) {
        guard let id = activeID else { return }
        queue = AppQueue.update(id, in: queue) { app in
            if on {
                app.checkedPaths.insert(path)
            } else {
                app.checkedPaths.remove(path)
            }
        }
    }

    func rescanQueue() {
        scanTicket += 1
        queue = queue.map { app in
            var copy = app
            copy.phase = .pending
            copy.items = []
            copy.checkedPaths = []
            copy.accessIssues = []
            copy.failureMessage = nil
            copy.cleanedSummary = nil
            return copy
        }
        showPermissionGuide = false
        settingsOpenFailed = false
        ensureScanLoop()
    }

    func requestTrash(_ mode: TrashConfirmMode) {
        trashConfirmMode = mode
        switch mode {
        case .current:
            guard let app = activeApp, !app.checkedPaths.isEmpty, app.phase == .ready else { return }
        case .queue:
            guard cleanableCount > 0 else { return }
        }
        showTrashConfirm = true
    }

    func confirmTrash() {
        showTrashConfirm = false
        guard !isTrashing, !isScanning else { return }
        let ids: [String]
        switch trashConfirmMode {
        case .current:
            guard let id = activeID else { return }
            ids = [id]
        case .queue:
            ids = AppQueue.cleanOrder(queue)
        }
        guard !ids.isEmpty else { return }

        isTrashing = true
        var totalCount = 0
        var totalBytes: UInt64 = 0
        var failures: [TrashMover.TrashFailure] = []
        var appsCleaned = 0

        for id in ids {
            guard let current = queue.first(where: { $0.id == id }) else { continue }
            let targets = current.items.filter { current.checkedPaths.contains($0.path) }
            guard !targets.isEmpty else { continue }
            queue = AppQueue.update(id, in: queue) { $0.phase = .cleaning }
            activeID = id
            let paths = targets.map(\.path)
            let sizes = Dictionary(uniqueKeysWithValues: targets.map { ($0.path, $0.byteSize) })
            let result = TrashMover.moveToTrash(paths: paths, byteSizes: sizes)
            let moved = Set(result.moved)
            queue = AppQueue.update(id, in: queue) { item in
                item.items.removeAll { moved.contains($0.path) }
                item.checkedPaths.subtract(moved)
                item.cleanedSummary = result.summary
                if item.items.isEmpty {
                    item.phase = .cleaned
                    item.failureMessage = nil
                } else {
                    item.phase = .ready
                    if !result.failed.isEmpty {
                        item.failureMessage = "Some items stayed in place. Grant access if macOS blocked them, then try again."
                    }
                }
            }
            totalCount += result.moved.count
            totalBytes &+= result.freedBytes
            failures.append(contentsOf: result.failed)
            appsCleaned += 1
        }

        isTrashing = false
        lastSummary = ResidueSummary(itemCount: totalCount, totalBytes: totalBytes)
        lastFailures = failures
        lastCleanedAppCount = appsCleaned
        showSummary = true
        if failures.contains(where: \.permissionDenied) {
            showPermissionGuide = true
        }
    }

    func dismissPermissionGuide() {
        showPermissionGuide = false
    }

    func openPermissionSettings() {
        let kind = accessIssues.first?.kind ?? .fullDiskAccess
        settingsOpenFailed = !SystemSettingsOpener.open(kind)
        if settingsOpenFailed {
            showPermissionGuide = true
        }
    }

    func setSafetyLevel(_ level: SafetyLevel) {
        settings.safetyLevel = level
        SweepPreferences.save(settings)
    }

    func setCategory(_ category: ResidueCategory, enabled: Bool) {
        if category == .application { return }
        if enabled {
            settings.enabledCategories.insert(category)
        } else {
            settings.enabledCategories.remove(category)
        }
        SweepPreferences.save(settings)
    }

    func setIncludeAppBundle(_ on: Bool) {
        settings.includeAppBundle = on
        SweepPreferences.save(settings)
    }

    func restoreDefaultSettings() {
        settings = .default
        SweepPreferences.save(settings)
    }

    private func ensureScanLoop() {
        guard !scanLoopActive else { return }
        scanLoopActive = true
        let ticket = scanTicket
        Task { @MainActor in
            self.isScanning = true
            while ticket == self.scanTicket, let next = AppQueue.nextToScan(self.queue) {
                await self.scanOne(id: next.id, ticket: ticket)
            }
            let current = ticket == self.scanTicket
            self.isScanning = false
            self.scanLoopActive = false
            if current {
                self.showPermissionGuide = !self.accessIssues.isEmpty
            } else if self.queue.contains(where: { $0.phase == .pending }) {
                self.ensureScanLoop()
            }
        }
    }

    private func scanOne(id: String, ticket: Int) async {
        guard ticket == scanTicket else { return }
        guard let info = queue.first(where: { $0.id == id })?.info else { return }
        activeID = id

        if ResidueRules.isBlockedBundleID(info.bundleIdentifier) {
            queue = AppQueue.update(id, in: queue) { app in
                app.phase = .skipped
                app.items = []
                app.checkedPaths = []
                app.accessIssues = []
                app.failureMessage = "Skipped. Apple and system apps are never cleaned."
            }
            return
        }

        queue = AppQueue.update(id, in: queue) { app in
            app.phase = .scanning
            app.failureMessage = nil
        }
        let settings = self.settings
        let report = await Task.detached(priority: .userInitiated) {
            ResidueScanner.scanReport(for: info, options: .init(), settings: settings)
        }.value
        guard ticket == scanTicket else { return }
        queue = AppQueue.update(id, in: queue) { app in
            app.phase = .ready
            app.items = report.items
            app.checkedPaths = Set(report.items.map(\.path))
            app.accessIssues = report.accessIssues
            app.failureMessage = nil
            app.cleanedSummary = nil
        }
    }

    private static func url(fromDropItem item: Any?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
            return url
        }
        if let str = item as? String {
            if let url = URL(string: str), url.isFileURL {
                return url
            }
            return URL(fileURLWithPath: str)
        }
        return nil
    }
}

enum SystemSettingsOpener {
    @MainActor
    static func open(_ kind: AccessKind) -> Bool {
        for url in PermissionGuide.settingsURLs(for: kind) {
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }
}
