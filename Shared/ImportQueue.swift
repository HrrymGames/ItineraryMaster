import Foundation

/// The shared App Group container used to hand links from the share sheet to the app.
///
/// SideStore / AltStore rename app groups when they re-sign an app (they append
/// your team ID) and record the new names under `ALTAppGroups` in Info.plist,
/// so we look there first and fall back to the name we built with.
enum AppGroup {
    static var candidateIdentifiers: [String] {
        var ids: [String] = []
        func collect(from bundle: Bundle?) {
            guard let bundle else { return }
            if let groups = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] { ids += groups }
            if let id = bundle.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String { ids.append(id) }
        }
        collect(from: .main)
        // Inside the share extension, the host app's bundle is two levels up (App.app/PlugIns/X.appex).
        if Bundle.main.bundleURL.pathExtension == "appex" {
            collect(from: Bundle(url: Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()))
        }
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    static var containerURL: URL? {
        for id in candidateIdentifiers {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                return url
            }
        }
        return nil
    }
}

struct PendingImport: Codable, Equatable {
    var url: String
    var note: String?
    var date: Date
    /// VideoFolder raw value chosen in the share sheet.
    var folder: String?
}

enum ImportQueue {
    private static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent("pending_imports.json")
    }

    static var isAvailable: Bool { fileURL != nil }

    /// Adds a link for the app to pick up next time it opens. Returns false if
    /// the shared container isn't available (e.g. app groups weren't signed in).
    @discardableResult
    static func append(_ item: PendingImport) -> Bool {
        guard let url = fileURL else { return false }
        let coordinator = NSFileCoordinator()
        var ok = false
        var error: NSError?
        coordinator.coordinate(writingItemAt: url, options: [], error: &error) { target in
            var list = read(at: target)
            if !list.contains(where: { $0.url == item.url }) { list.append(item) }
            ok = write(list, to: target)
        }
        return ok && error == nil
    }

    /// Returns and clears everything waiting in the queue.
    static func drain() -> [PendingImport] {
        guard let url = fileURL, FileManager.default.fileExists(atPath: url.path) else { return [] }
        let coordinator = NSFileCoordinator()
        var items: [PendingImport] = []
        var error: NSError?
        coordinator.coordinate(writingItemAt: url, options: [], error: &error) { target in
            items = read(at: target)
            if !items.isEmpty { _ = write([], to: target) }
        }
        return items
    }

    private static func read(at url: URL) -> [PendingImport] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return (try? d.decode([PendingImport].self, from: data)) ?? []
    }

    private static func write(_ items: [PendingImport], to url: URL) -> Bool {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        guard let data = try? e.encode(items) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
