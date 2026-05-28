import SwiftUI
import ServiceManagement

/**
 * 设置视图
 */
struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        Form {
            Section {
                Picker("主题", selection: $settings.theme) {
                    Text("跟随系统").tag(Theme.system)
                    Text("浅色").tag(Theme.light)
                    Text("深色").tag(Theme.dark)
                }
                .pickerStyle(.menu)
                .onChange(of: settings.theme) { _ in
                    settings.saveSettings()
                    // 立即应用主题
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.applyTheme()
                    }
                }
            } header: {
                Text("主题")
            }
            
            Section {
                Toggle("开机自动启动", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _ in
                        settings.toggleLaunchAtLogin()
                    }
                
                Picker("单击切换上一个应用", selection: $settings.lastAppSwitchTrigger) {
                    ForEach(LastAppSwitchTrigger.allCases, id: \.self) { trigger in
                        Text(trigger.description).tag(trigger)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.lastAppSwitchTrigger) { _ in
                        settings.saveSettings()
                }

                Picker("Option 键启用方式", selection: $settings.optionKeyActivationMode) {
                    ForEach(OptionKeyActivationMode.allCases, id: \.self) { mode in
                        Text(mode.description).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.optionKeyActivationMode) { _ in
                    settings.saveSettings()
                }
                
                HStack {
                    Text("辅助功能权限")
                    Spacer()
                    if AXIsProcessTrusted() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("前往设置") {
                            let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                            NSWorkspace.shared.open(prefpaneUrl)
                        }
                    }
                }
            } header: {
                Text("通用")
            }
            
            Section {
                Link(destination: URL(string: "https://github.com/lessismoretest/Opti")!) {
                    HStack {
                        GitHubIcon()
                            .foregroundColor(.primary)
                        Text("GitHub 仓库")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                }
            } header: {
                Text("关于")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 500)
    }
}

// GitHub 图标组件
struct GitHubIcon: View {
    var body: some View {
        Image("github")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
    }
}
