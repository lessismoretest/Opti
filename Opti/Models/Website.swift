import Foundation
import AppKit

/**
 * 网站模型
 */
struct Website: Identifiable, Codable, Equatable {
    let id: UUID
    var url: String
    var shortcutKey: String?
    var isEnabled: Bool = true

    private static let semaphore = DispatchSemaphore(value: 3)
    private static var loadingQueue = Set<String>()
    private static let queueLock = NSLock()

    init(id: UUID = UUID(), url: String, shortcutKey: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.url = url
        self.shortcutKey = shortcutKey
        self.isEnabled = isEnabled
    }

    var displayName: String {
        URL(string: url)?.host ?? url
    }

    static func == (lhs: Website, rhs: Website) -> Bool {
        lhs.id == rhs.id &&
        lhs.url == rhs.url &&
        lhs.shortcutKey == rhs.shortcutKey &&
        lhs.isEnabled == rhs.isEnabled
    }

    func fetchIcon(completion: @escaping (NSImage?) -> Void) async {
        Website.queueLock.lock()
        if Website.loadingQueue.contains(url) {
            Website.queueLock.unlock()
            return
        }
        Website.loadingQueue.insert(url)
        Website.queueLock.unlock()

        defer {
            Website.queueLock.lock()
            Website.loadingQueue.remove(url)
            Website.queueLock.unlock()
        }

        Website.semaphore.wait()
        defer { Website.semaphore.signal() }

        guard let url = URL(string: self.url) else {
            completion(nil)
            return
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        let session = URLSession(configuration: config)

        if let faviconURL = URL(string: "\(url.scheme ?? "https")://\(url.host ?? "")/favicon.ico") {
            do {
                let (data, _) = try await session.data(from: faviconURL)
                if let image = NSImage(data: data) {
                    completion(image)
                    return
                }
            } catch {
            }
        }

        if let host = url.host,
           let googleFaviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") {
            do {
                let (data, _) = try await session.data(from: googleFaviconURL)
                if let image = NSImage(data: data) {
                    completion(image)
                    return
                }
            } catch {
            }
        }

        completion(nil)
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}

/**
 * 网站管理器
 */
class WebsiteManager: ObservableObject {
    static let shared = WebsiteManager()

    @Published var websites: [Website] = [] {
        didSet {
            saveWebsites()
        }
    }

    private let websitesKey = "Websites"

    private init() {
        loadWebsites()
    }

    func getWebsites() -> [Website] {
        websites.sorted(by: { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending })
    }

    func addWebsite(_ website: Website) {
        websites.append(website)
    }

    func updateWebsite(_ website: Website) {
        if let index = websites.firstIndex(where: { $0.id == website.id }), websites[index] != website {
            websites[index] = website
        }
    }

    func deleteWebsite(_ website: Website) {
        websites.removeAll { $0.id == website.id }
    }

    func setShortcut(_ key: String?, for websiteId: UUID) {
        if let index = websites.firstIndex(where: { $0.id == websiteId }) {
            var website = websites[index]
            website.shortcutKey = key
            websites[index] = website
        }
    }

    private func loadWebsites() {
        if let data = UserDefaults.standard.data(forKey: websitesKey) {
            do {
                var loadedWebsites = try JSONDecoder().decode([Website].self, from: data)

                var uniqueWebsites: [String: Website] = [:]
                for website in loadedWebsites {
                    if uniqueWebsites[website.url] == nil {
                        uniqueWebsites[website.url] = website
                    }
                }
                loadedWebsites = Array(uniqueWebsites.values)
                websites = loadedWebsites
            } catch {
                optiDebugLog("[WebsiteManager] ❌ 加载网站数据失败: \(error)")
            }
        }
    }

    private func saveWebsites() {
        do {
            let data = try JSONEncoder().encode(websites)
            UserDefaults.standard.set(data, forKey: websitesKey)
        } catch {
            optiDebugLog("[WebsiteManager] ❌ 保存网站数据失败: \(error)")
        }
    }
}
