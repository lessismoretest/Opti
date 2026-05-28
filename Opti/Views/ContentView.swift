import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            List {
                // 顶部应用名标题
                Text("Opti")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                
                NavigationLink(destination: ShortcutsView()
                    .navigationTitle("App快捷键")) {
                    Label("App快捷键", systemImage: "keyboard")
                }
                
                NavigationLink(destination: WebShortcutsView()
                    .navigationTitle("网站快捷键")) {
                    Label("网站快捷键", systemImage: "globe")
                }
                
                NavigationLink(destination: CircleRingSettingsView()
                    .navigationTitle("圆环模式")) {
                    Label("圆环模式", systemImage: "circle.dashed")
                }
                
                NavigationLink(destination: SettingsView()
                    .navigationTitle("通用设置")) {
                    Label("通用设置", systemImage: "gear")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Spacer()
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: toggleSidebar) {
                        Image(systemName: "sidebar.left")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text("选择左侧选项进行设置")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Opti")
        }
    }
    
    private func toggleSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
} 
