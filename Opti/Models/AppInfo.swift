import Foundation
import AppKit

struct CircleRingAppSlot: Equatable {
    enum State: Equatable {
        case available(URL)
        case unavailable
        case unconfigured
    }

    let index: Int
    let bundleId: String
    let state: State

    var url: URL? {
        if case .available(let url) = state {
            return url
        }
        return nil
    }

    static func resolve(
        configuredBundleIdentifiers: [String],
        sectorCount: Int,
        applicationURL: (String) -> URL?
    ) -> [CircleRingAppSlot] {
        guard !configuredBundleIdentifiers.isEmpty, sectorCount > 0 else {
            return []
        }

        return (0..<sectorCount).map { index in
            guard index < configuredBundleIdentifiers.count else {
                return CircleRingAppSlot(index: index, bundleId: "", state: .unconfigured)
            }

            let bundleId = configuredBundleIdentifiers[index]
            guard !bundleId.isEmpty else {
                return CircleRingAppSlot(index: index, bundleId: "", state: .unconfigured)
            }

            if let url = applicationURL(bundleId) {
                return CircleRingAppSlot(index: index, bundleId: bundleId, state: .available(url))
            }

            return CircleRingAppSlot(index: index, bundleId: bundleId, state: .unavailable)
        }
    }
}

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
