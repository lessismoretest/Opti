import SwiftUI

struct ShortcutsView: View {
    @StateObject private var settings = AppSettings.shared
    
    private let availableKeys = (1...9).map(String.init) + (65...90).map { String(UnicodeScalar($0)) }
    
    var body: some View {
        VStack(spacing: 16) {
            List {
                ForEach(availableKeys, id: \.self) { key in
                    ShortcutRow(key: key)
                }
            }
            .listStyle(InsetListStyle())
        }
        .padding()
    }
}

struct ShortcutRow: View {
    let key: String
    @StateObject private var settings = AppSettings.shared
    @StateObject private var hotKeyManager = HotKeyManager.shared
    @State private var isSelectingApp = false
    
    private var shortcut: AppShortcut? {
        settings.shortcuts.first { $0.key == key }
    }
    
    var body: some View {
        HStack {
            Text("Option + \(key)")
                .frame(width: 100, alignment: .leading)
            
            if let shortcut = shortcut {
                HStack {
                    if let icon = appIcon(for: shortcut.bundleIdentifier) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    Text(shortcut.appName)
                }
                .frame(width: 200, alignment: .leading)
                
                Button("移除") {
                    settings.shortcuts.removeAll { $0.key == key }
                    settings.saveSettings()
                    hotKeyManager.updateShortcuts()
                }
            } else {
                Button("选择应用") {
                    isSelectingApp.toggle()
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $isSelectingApp) {
            AppSelectionView(key: key)
        }
    }

    private func appIcon(for bundleIdentifier: String) -> NSImage? {
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
           let icon = runningApp.icon {
            return icon
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return nil
    }
} 
