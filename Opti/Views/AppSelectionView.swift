import SwiftUI

struct AppSelectionView: View {
    private struct AppCandidate: Identifiable, Hashable {
        let bundleId: String
        let name: String
        let appURL: URL
        let searchableText: String

        var id: String { bundleId }
    }

    private let key: String?
    private let titleText: String
    private let selectedBundleId: String?
    private let onSelect: ((String, String) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = AppSettings.shared
    @StateObject private var hotKeyManager = HotKeyManager.shared
    @State private var searchText = ""
    @State private var allApps: [AppCandidate] = []
    @State private var isLoading = false

    init(key: String) {
        self.key = key
        self.titleText = "选择要绑定到 Option + \(key) 的应用"
        self.selectedBundleId = nil
        self.onSelect = nil
    }

    init(title: String, selectedBundleId: String? = nil, onSelect: @escaping (String, String) -> Void) {
        self.key = nil
        self.titleText = title
        self.selectedBundleId = selectedBundleId
        self.onSelect = onSelect
    }

    private var filteredApps: [AppCandidate] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !keyword.isEmpty else { return allApps }
        return allApps.filter { $0.searchableText.contains(keyword) }
    }
    
    // 检查应用是否已绑定到当前键
    private func isAppSelected(bundleId: String) -> Bool {
        if let key {
            return settings.shortcuts.contains { $0.key == key && $0.bundleIdentifier == bundleId }
        }
        return selectedBundleId == bundleId
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(titleText)
                .font(.headline)
                .padding()
            
            // 搜索栏
            TextField("搜索应用...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            if isLoading && allApps.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("正在加载应用列表...")
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredApps) { app in
                        AppRowView(
                            icon: NSWorkspace.shared.icon(forFile: app.appURL.path),
                            name: app.name,
                            bundleId: app.bundleId,
                            isSelected: isAppSelected(bundleId: app.bundleId)
                        ) {
                            handleSelection(bundleId: app.bundleId, name: app.name)
                        }
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .task {
            await loadAppsIfNeeded()
        }
    }
    
    private func handleSelection(bundleId: String, name: String) {
        if let key {
            let shortcut = AppShortcut(
                key: key,
                bundleIdentifier: bundleId,
                appName: name
            )
            settings.shortcuts.removeAll { $0.key == key }
            settings.shortcuts.append(shortcut)
            settings.saveSettings()
            hotKeyManager.updateShortcuts()
        } else {
            onSelect?(bundleId, name)
        }
        dismiss()
    }

    @MainActor
    private func loadAppsIfNeeded() async {
        guard allApps.isEmpty, !isLoading else { return }
        isLoading = true
        let apps = await Task.detached(priority: .userInitiated) {
            Self.scanInstalledApps()
        }.value
        allApps = apps
        isLoading = false
    }

    nonisolated private static func scanInstalledApps() -> [AppCandidate] {
        let appDirectories = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Library/CoreServices"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var uniqueAppsByBundleId: [String: AppCandidate] = [:]
        for directory in appDirectories {
            guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
                continue
            }

            for entry in entries where entry.hasSuffix(".app") {
                let appURL = directory.appendingPathComponent(entry)
                guard let bundle = Bundle(url: appURL),
                      let bundleId = bundle.bundleIdentifier,
                      uniqueAppsByBundleId[bundleId] == nil,
                      let candidate = buildCandidate(appURL: appURL, bundle: bundle, bundleId: bundleId) else {
                    continue
                }
                uniqueAppsByBundleId[bundleId] = candidate
            }
        }

        // Finder 在部分系统版本位于 CoreServices，兜底确保可选
        if uniqueAppsByBundleId["com.apple.finder"] == nil {
            let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            if FileManager.default.fileExists(atPath: finderURL.path),
               let bundle = Bundle(url: finderURL),
               let bundleId = bundle.bundleIdentifier,
               let candidate = buildCandidate(appURL: finderURL, bundle: bundle, bundleId: bundleId) {
                uniqueAppsByBundleId[bundleId] = candidate
            }
        }

        return uniqueAppsByBundleId.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func buildCandidate(appURL: URL, bundle: Bundle, bundleId: String) -> AppCandidate? {
        let localizedDisplayName = FileManager.default.displayName(atPath: appURL.path)
        let bundleDisplayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        let fileName = appURL.deletingPathExtension().lastPathComponent
        let aliases = aliasKeywords(for: bundleId)

        let nameCandidates = [localizedDisplayName, fileName] + [bundleDisplayName, bundleName].compactMap { $0 }
        let name = nameCandidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? fileName

        let searchableTokens = [localizedDisplayName, fileName, bundleId] +
            [bundleDisplayName, bundleName].compactMap { $0 } +
            aliases
        let searchableText = Array(Set(searchableTokens.map { $0.lowercased() })).joined(separator: " ")

        return AppCandidate(
            bundleId: bundleId,
            name: name,
            appURL: appURL,
            searchableText: searchableText
        )
    }

    nonisolated private static func aliasKeywords(for bundleId: String) -> [String] {
        let aliasMap: [String: [String]] = [
            "com.apple.finder": ["访达", "finder"],
            "com.apple.Photos": ["照片", "photos", "相册"],
            "com.apple.Safari": ["safari", "浏览器", "safari浏览器"],
            "com.apple.systempreferences": ["系统设置", "系统偏好设置", "system settings"],
            "com.apple.mail": ["邮件", "mail"],
            "com.apple.MobileSMS": ["信息", "messages", "短信"],
            "com.apple.Notes": ["备忘录", "notes"],
            "com.apple.reminders": ["提醒事项", "reminders"],
            "com.apple.iCal": ["日历", "calendar"],
            "com.apple.Music": ["音乐", "music"],
            "com.apple.calculator": ["计算器", "calculator"],
            "com.apple.Preview": ["预览", "preview"]
        ]
        return aliasMap[bundleId] ?? []
    }
}

// 抽取的应用行视图组件
struct AppRowView: View {
    let icon: NSImage?
    let name: String
    let bundleId: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 32, height: 32)
                }
                VStack(alignment: .leading) {
                    Text(name)
                        .fontWeight(.medium)
                    Text(bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
