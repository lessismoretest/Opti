import AppKit

@MainActor
final class ApplicationInfoCache {
    static let shared = ApplicationInfoCache()

    private struct Entry {
        let info: AppInfo?
        let expiresAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let applicationURL: (String) -> URL?
    private let applicationIcon: (URL) -> NSImage
    private let now: () -> Date

    init(
        applicationURL: @escaping (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
        applicationIcon: @escaping (URL) -> NSImage = { NSWorkspace.shared.icon(forFile: $0.path) },
        now: @escaping () -> Date = Date.init
    ) {
        self.applicationURL = applicationURL
        self.applicationIcon = applicationIcon
        self.now = now
    }

    func info(for bundleID: String) -> AppInfo? {
        guard !bundleID.isEmpty else { return nil }
        let date = now()
        if let entry = entries[bundleID], date < entry.expiresAt {
            return entry.info
        }

        let info = applicationURL(bundleID).map { url in
            AppInfo(bundleId: bundleID, name: url.deletingPathExtension().lastPathComponent,
                    icon: applicationIcon(url), url: url)
        }
        // 定期重新解析安装位置；不存在的应用更快重试，避免负缓存阻挡新安装的应用。
        entries[bundleID] = Entry(info: info, expiresAt: date.addingTimeInterval(info == nil ? 5 : 60))
        return info
    }

    func retain(bundleIDs: [String]) {
        let configuredIDs = Set(bundleIDs)
        entries = entries.filter { configuredIDs.contains($0.key) }
    }
}
