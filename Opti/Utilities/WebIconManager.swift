import SwiftUI
import AppKit

@MainActor
class WebIconManager: ObservableObject {
    static let shared = WebIconManager()

    @Published private var icons: [String: NSImage] = [:]

    private struct Request {
        let id = UUID()
        let website: Website
        var task: Task<Void, Never>?
        var completions: [(NSImage?) -> Void] = []
    }

    private let cacheDirectory: URL
    private let session: URLSession
    private let fileQueue = DispatchQueue(label: "com.zisa.Opti.website-icons", qos: .utility)
    private var requests: [String: Request] = [:]
    private var pendingKeys: [String] = []
    private var retryAfter: [String: Date] = [:]

    init(cacheDirectory: URL? = nil, session: URLSession = .shared) {
        self.cacheDirectory = cacheDirectory ??
            (FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ??
             FileManager.default.temporaryDirectory).appendingPathComponent("website_icons")
        self.session = session
    }

    func getCachedIconCount() -> Int { icons.count }

    func preloadIcons(for websites: [Website]) {
        websites.forEach { loadIcon(for: $0) }
    }

    // 视图绘制时只查内存；磁盘读取和网络请求统一由 loadIcon 负责。
    func icon(for website: Website) -> NSImage? {
        icons[cacheKey(for: website)]
    }

    func setIcon(_ icon: NSImage, for website: Website) {
        let key = cacheKey(for: website)
        let request = removeRequest(for: key)
        retryAfter[key] = nil
        store(icon, for: website)
        startPendingRequests()
        request?.completions.forEach { $0(icon) }
    }

    func loadIcon(for website: Website, completion: ((NSImage?) -> Void)? = nil) {
        let key = cacheKey(for: website)
        if let icon = icons[key] {
            completion?(icon)
            return
        }
        if let date = retryAfter[key], Date() < date {
            completion?(nil)
            return
        }
        if requests[key] == nil {
            // 修改网址后取消同一网站的旧请求，旧结果不能覆盖新图标。
            cancelLoading(for: website.id)
            requests[key] = Request(website: website)
            pendingKeys.append(key)
        }
        if let completion {
            requests[key]?.completions.append(completion)
        }
        startPendingRequests()
    }

    private func startPendingRequests() {
        // 等待中的请求只排队，不阻塞 Swift 并发线程。
        while requests.values.filter({ $0.task != nil }).count < 3, !pendingKeys.isEmpty {
            let key = pendingKeys.removeFirst()
            guard let request = requests[key] else { continue }
            requests[key]?.task = Task { [weak self] in
                guard let self else { return }
                let path = self.cacheDirectory.appendingPathComponent("\(key).png")
                let cachedData: Data? = await withCheckedContinuation { continuation in
                    self.fileQueue.async {
                        continuation.resume(returning: try? Data(contentsOf: path))
                    }
                }
                guard !Task.isCancelled else { return }
                let cachedIcon = cachedData.flatMap(NSImage.init(data:))
                let icon: NSImage?
                if let cachedIcon {
                    icon = cachedIcon
                } else {
                    icon = await self.fetchIcon(for: request.website)
                }
                guard !Task.isCancelled, self.requests[key]?.id == request.id else { return }
                let completed = self.requests.removeValue(forKey: key)
                if let icon {
                    if cachedIcon != nil {
                        self.icons[key] = icon
                    } else {
                        self.store(icon, for: request.website)
                    }
                    self.retryAfter[key] = nil
                } else {
                    self.retryAfter[key] = Date().addingTimeInterval(30)
                }
                self.startPendingRequests()
                completed?.completions.forEach { $0(icon) }
            }
        }
    }

    private func fetchIcon(for website: Website) async -> NSImage? {
        guard let url = URL(string: website.url), let host = url.host,
              let faviconURL = URL(string: "\(url.scheme ?? "https")://\(host)\(url.port.map { ":\($0)" } ?? "")/favicon.ico"),
              let fallbackURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") else {
            return nil
        }
        for candidate in [faviconURL, fallbackURL] {
            guard !Task.isCancelled else { return nil }
            do {
                let (data, response) = try await session.data(for: URLRequest(url: candidate, timeoutInterval: 5))
                guard !Task.isCancelled else { return nil }
                if let response = response as? HTTPURLResponse,
                   (200..<300).contains(response.statusCode), let image = NSImage(data: data) {
                    return image
                }
            } catch {
                if Task.isCancelled { return nil }
            }
        }
        return nil
    }

    private func store(_ icon: NSImage, for website: Website) {
        icons[cacheKey(for: website)] = icon
        guard let data = icon.pngData() else { return }
        let directory = cacheDirectory
        let path = directory.appendingPathComponent("\(cacheKey(for: website)).png")
        let legacyPath = directory.appendingPathComponent("\(website.id.uuidString).png")
        fileQueue.async {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(to: path, options: .atomic)
            try? FileManager.default.removeItem(at: legacyPath)
        }
    }

    private func removeRequest(for key: String) -> Request? {
        let request = requests.removeValue(forKey: key)
        request?.task?.cancel()
        pendingKeys.removeAll { $0 == key }
        return request
    }

    func cancelLoading(for websiteId: UUID) {
        let prefix = "\(websiteId.uuidString)-"
        let cancelled = requests.keys.filter { $0.hasPrefix(prefix) }.compactMap { removeRequest(for: $0) }
        startPendingRequests()
        cancelled.forEach { $0.completions.forEach { $0(nil) } }
    }

    func clearCache() {
        let cancelled = Array(requests.values)
        requests.removeAll()
        pendingKeys.removeAll()
        cancelled.forEach { $0.task?.cancel() }
        retryAfter.removeAll()
        icons.removeAll()
        let directory = cacheDirectory
        // 与缓存写入共用串行队列，避免清除后旧写入又把图标写回来。
        fileQueue.async { try? FileManager.default.removeItem(at: directory) }
        cancelled.forEach { $0.completions.forEach { $0(nil) } }
    }

    func getCacheSize() async -> Int64 {
        let directory = cacheDirectory
        return await withCheckedContinuation { continuation in
            fileQueue.async {
                let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey])
                var size: Int64 = 0
                while let url = files?.nextObject() as? URL {
                    size += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                }
                continuation.resume(returning: size)
            }
        }
    }

    private func cacheKey(for website: Website) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in website.url.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return "\(website.id.uuidString)-\(String(format: "%016llx", hash))"
    }
}
