import SwiftUI

/**
 * 网站快捷键视图
 */
struct WebShortcutsView: View {
    private let keys = (1...9).map(String.init) + (65...90).map { String(UnicodeScalar($0)) }

    var body: some View {
        VStack(spacing: 16) {
            List {
                ForEach(keys, id: \.self) { key in
                    WebShortcutRow(key: key)
                }
            }
            .listStyle(InsetListStyle())
        }
        .padding()
    }
}

/**
 * 网站快捷键行视图
 */
struct WebShortcutRow: View {
    let key: String
    @StateObject private var websiteManager = WebsiteManager.shared
    @StateObject private var hotKeyManager = HotKeyManager.shared
    @ObservedObject private var iconManager = WebIconManager.shared
    @State private var showingBindSheet = false

    private var website: Website? {
        websiteManager.getWebsites().first { $0.shortcutKey == key }
    }

    private var keyText: String {
        if let num = Int(key) {
            return "Option + Command + \(num)"
        }
        return "Option + Command + \(key)"
    }

    var body: some View {
        HStack {
            Text(keyText)
                .frame(width: 180, alignment: .leading)
                .font(.system(.body, design: .monospaced))

            if let website = website {
                HStack {
                    if let icon = iconManager.icon(for: website) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "globe")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    Text(website.displayName)
                }
                .frame(width: 240, alignment: .leading)

                Button("移除") {
                    var updatedWebsite = website
                    updatedWebsite.shortcutKey = nil
                    websiteManager.updateWebsite(updatedWebsite)
                    hotKeyManager.updateShortcuts()
                }
            } else {
                Button("输入网址绑定") {
                    showingBindSheet = true
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingBindSheet) {
            WebsiteShortcutBindingView(key: key)
        }
        .onAppear {
            if let website = website {
                iconManager.loadIcon(for: website)
            }
        }
        .onChange(of: website?.id) { _ in
            if let website = website {
                iconManager.loadIcon(for: website)
            }
        }
    }
}

/**
 * 网站快捷键绑定视图（只需输入网址）
 */
struct WebsiteShortcutBindingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var websiteManager = WebsiteManager.shared
    @StateObject private var hotKeyManager = HotKeyManager.shared

    let key: String
    @State private var urlText = ""
    @State private var showInvalidURLAlert = false

    var body: some View {
        VStack(spacing: 16) {
            Text("绑定网站快捷键")
                .font(.headline)

            Text("按键：Option + Command + \(key)")
                .foregroundColor(.secondary)

            TextField("输入网站网址（如 https://example.com）", text: $urlText)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("绑定") {
                    bindShortcut()
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
        .alert("网址无效", isPresented: $showInvalidURLAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请输入有效的网址")
        }
    }

    private func normalizeURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.host != nil {
            return url.absoluteString
        }

        let withScheme = "https://\(trimmed)"
        if let url = URL(string: withScheme), url.host != nil {
            return url.absoluteString
        }

        return nil
    }

    private func bindShortcut() {
        guard let normalized = normalizeURL(urlText) else {
            showInvalidURLAlert = true
            return
        }

        // 清除当前快捷键已绑定的网站，确保一个按键只绑定一个网站
        for site in websiteManager.getWebsites().filter({ $0.shortcutKey == key }) {
            var updated = site
            updated.shortcutKey = nil
            websiteManager.updateWebsite(updated)
        }

        if var existing = websiteManager.getWebsites().first(where: { $0.url == normalized }) {
            existing.shortcutKey = key
            websiteManager.updateWebsite(existing)
        } else {
            let newWebsite = Website(url: normalized, shortcutKey: key)
            websiteManager.addWebsite(newWebsite)
        }

        hotKeyManager.updateShortcuts()
        dismiss()
    }
}
