import Foundation

public struct AppBundleInfo: Equatable, Sendable, Identifiable {
    public var id: String { bundleIdentifier + "|" + path }
    public var name: String
    public var bundleIdentifier: String
    public var path: String
    public var shortVersion: String?
    public var bundleVersion: String?

    public init(
        name: String,
        bundleIdentifier: String,
        path: String,
        shortVersion: String? = nil,
        bundleVersion: String? = nil
    ) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.shortVersion = shortVersion
        self.bundleVersion = bundleVersion
    }
}

public enum AppBundleReaderError: Error, LocalizedError, Equatable {
    case notAnApp(String)
    case missingInfoPlist(String)
    case missingBundleIdentifier(String)
    case unreadablePlist(String)

    public var errorDescription: String? {
        switch self {
        case .notAnApp(let p): return "Not an .app bundle: \(p)"
        case .missingInfoPlist(let p): return "Missing Info.plist: \(p)"
        case .missingBundleIdentifier(let p): return "CFBundleIdentifier missing in \(p)"
        case .unreadablePlist(let p): return "Could not read Info.plist: \(p)"
        }
    }
}

/// Reads Bundle ID and path from a dropped / chosen `.app`.
public enum AppBundleReader {
    public static func read(url: URL) throws -> AppBundleInfo {
        var isDir: ObjCBool = false
        let path = url.path
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            throw AppBundleReaderError.notAnApp(path)
        }
        guard path.hasSuffix(".app") || url.pathExtension.lowercased() == "app" else {
            throw AppBundleReaderError.notAnApp(path)
        }

        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else {
            throw AppBundleReaderError.missingInfoPlist(plistURL.path)
        }

        let data: Data
        do {
            data = try Data(contentsOf: plistURL)
        } catch {
            throw AppBundleReaderError.unreadablePlist(plistURL.path)
        }

        let plist: [String: Any]
        do {
            var format = PropertyListSerialization.PropertyListFormat.xml
            let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
            guard let dict = obj as? [String: Any] else {
                throw AppBundleReaderError.unreadablePlist(plistURL.path)
            }
            plist = dict
        } catch let e as AppBundleReaderError {
            throw e
        } catch {
            throw AppBundleReaderError.unreadablePlist(plistURL.path)
        }

        guard let bundleID = plist["CFBundleIdentifier"] as? String, !bundleID.isEmpty else {
            throw AppBundleReaderError.missingBundleIdentifier(plistURL.path)
        }

        let name = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        return AppBundleInfo(
            name: name,
            bundleIdentifier: bundleID,
            path: path,
            shortVersion: plist["CFBundleShortVersionString"] as? String,
            bundleVersion: plist["CFBundleVersion"] as? String
        )
    }
}
