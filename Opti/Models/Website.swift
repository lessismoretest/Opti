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
}

// 保留配置中的每一个位置，绘制和松键打开使用相同的槽位映射。
struct CircleRingWebsiteSlot: Equatable {
    let index: Int
    let website: Website?
    let url: URL?

    static func resolve(configuredIDs: [String], sectorCount: Int, websites: [Website]) -> [Self] {
        guard sectorCount > 0 else { return [] }
        let websitesByID = Dictionary(uniqueKeysWithValues: websites.map { ($0.id, $0) })
        return (0..<sectorCount).map { index in
            guard index < configuredIDs.count,
                  let id = UUID(uuidString: configuredIDs[index]),
                  let website = websitesByID[id],
                  let url = URL(string: website.url), url.host != nil else {
                return Self(index: index, website: nil, url: nil)
            }
            return Self(index: index, website: website, url: url)
        }
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
