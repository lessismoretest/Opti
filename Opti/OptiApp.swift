//
//  OptiApp.swift
//  Opti
//
//  Created by Less is more on 2025/1/15.
//

import SwiftUI
import AppKit
import ServiceManagement

func optiDebugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #else
    if ProcessInfo.processInfo.environment["DEBUG"] == "1" {
        print(message())
    }
    #endif
}

@main
struct OptiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings.shared
    
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
    
    private var colorScheme: ColorScheme? {
        switch settings.theme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotKeyManager: HotKeyManager?
    private var circleRingController: CircleRingController?
    private var activationObserver: NSObjectProtocol?

    deinit {
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保所有默认设置存在
        AppSettings.shared.ensureDefaultSettings()
        
        // 初始化热键管理器
        hotKeyManager = HotKeyManager.shared
        
        // 初始化圆环控制器 - 确保它在应用启动时就开始工作
        initializeCircleRingController()
        
        // 设置应用在后台运行时保持活跃
        NSApp.setActivationPolicy(.accessory)
        
        // 防止应用在最后一个窗口关闭时退出
        NSApp.activate(ignoringOtherApps: true)
        
        // 初始应用主题
        applyTheme()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 确保在应用终止前保存所有设置
        optiDebugLog("[AppDelegate] 应用即将终止，保存所有设置")
        ensureSettingsSaved()
        
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
            activationObserver = nil
        }
    }
    
    func applicationDidEnterBackground(_ notification: Notification) {
        // 确保在应用进入后台时保存所有设置
        optiDebugLog("[AppDelegate] 应用进入后台，保存所有设置")
        ensureSettingsSaved()
    }
    
    private func ensureSettingsSaved() {
        // 确保所有设置已保存
        AppSettings.shared.saveSettings()
        
        // 对于特别重要的设置，强制同步到磁盘
        // 注意：synchronize在现代macOS中已不推荐使用，但在某些情况下确保数据保存仍然有用
        // 特别是在应用即将终止的情况下
        UserDefaults.standard.synchronize()
    }
    
    // 初始化圆环控制器
    private func initializeCircleRingController() {
        optiDebugLog("[AppDelegate] 初始化圆环控制器")
        circleRingController = CircleRingController.shared
        
        // 确保圆环控制器被正确加载
        if circleRingController != nil {
            optiDebugLog("[AppDelegate] 圆环控制器已成功初始化")
            
            // 监听NSApplication的didBecomeActiveNotification以重新启用圆环控制器
            activationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main) { [weak self] _ in
                    optiDebugLog("[AppDelegate] 应用变为活跃状态，确保圆环控制器正常")
                    if self?.circleRingController == nil {
                        self?.ensureCircleRingControllerInitialized()
                    } else {
                        self?.circleRingController?.resetTransientState()
                    }
                }
        } else {
            optiDebugLog("[AppDelegate] ⚠️ 圆环控制器初始化失败")
        }
    }
    
    // 确保圆环控制器已初始化
    func ensureCircleRingControllerInitialized() {
        if circleRingController == nil {
            optiDebugLog("[AppDelegate] 重新初始化圆环控制器")
            initializeCircleRingController()
        } else {
            optiDebugLog("[AppDelegate] 圆环控制器已存在")
            circleRingController?.resetTransientState()
        }
    }
    
    func applyTheme() {
        let settings = AppSettings.shared
        let appearance: NSAppearance?
        
        switch settings.theme {
        case .light:
            appearance = NSAppearance(named: .aqua)
        case .dark:
            appearance = NSAppearance(named: .darkAqua)
        case .system:
            appearance = nil
        }
        
        DispatchQueue.main.async {
            // 应用到应用程序
            NSApp.appearance = appearance
            
            // 应用到所有窗口
            for window in NSApp.windows {
                window.appearance = appearance
                
                // 强制更新窗口和其内容
                if let contentView = window.contentView {
                    contentView.needsDisplay = true
                    contentView.needsLayout = true
                    
                    // 递归更新所有子视图
                    self.updateSubviews(of: contentView)
                }
                
                // 刷新窗口
                window.invalidateShadow()
                window.display()
            }
        }
    }
    
    private func updateSubviews(of view: NSView) {
        view.needsDisplay = true
        view.needsLayout = true
        
        for subview in view.subviews {
            updateSubviews(of: subview)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // 当用户点击 Dock 图标时显示主窗口
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        
        // 重新初始化圆环控制器，确保事件监听器正常
        if AppSettings.shared.enableCircleRingMode {
            ensureCircleRingControllerInitialized()
        }
        
        return true
    }
}
