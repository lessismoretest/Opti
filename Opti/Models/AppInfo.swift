import Foundation
import AppKit

/**
 * 应用信息模型
 */
struct AppInfo: Identifiable, Hashable {
    let id: String
    let bundleId: String
    let name: String
    let icon: NSImage
    let url: URL?
    
    init(bundleId: String, name: String, icon: NSImage, url: URL?) {
        self.id = bundleId
        self.bundleId = bundleId
        self.name = name
        self.icon = icon
        self.url = url
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        lhs.bundleId == rhs.bundleId
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleId)
    }
} 