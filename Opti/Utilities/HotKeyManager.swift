import Foundation
import Carbon
import AppKit

/**
 * 热键管理器
 */
class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    private let rightCommandKeyCode: CGKeyCode = 54
    private let leftOptionKeyCode: CGKeyCode = 58
    private let rightOptionKeyCode: CGKeyCode = 61
    @Published private var lastUpdateTime = Date()
    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var lastActiveApp: NSRunningApplication?
    private var localFlagsMonitor: Any?
    private var optionKeyMonitor: Any?
    private var isOptionKeyPressed = false
    private var isSwitchTriggerKeyPressed = false
    private var websiteManager = WebsiteManager.shared
    private var appSwitchObserver: Any?
    private var currentApp: NSRunningApplication?
    private var optionClickLastPressTime = Date.distantPast
    private var optionClickLastReleaseTime = Date.distantPast
    private var optionClickCount = 0
    private var optionClickPotentialDoubleClick = false
    private var optionSingleClickTimer: Timer?
    private var optionClickJustHandledDoubleClick = false
    private var activeOptionKeyCode: CGKeyCode?
    private var activeSwitchTriggerOptionKeyCode: CGKeyCode?
    
    // 数字键的键码映射
    private let numberKeyCodes: [Int: Int] = [
        1: 0x12, // 1
        2: 0x13, // 2
        3: 0x14, // 3
        4: 0x15, // 4
        5: 0x17, // 5
        6: 0x16, // 6
        7: 0x1A, // 7
        8: 0x1C, // 8
        9: 0x19  // 9
    ]
    
    // 字母键的键码映射
    private let letterKeyCodes: [String: Int] = [
        "A": 0x00,
        "B": 0x0B,
        "C": 0x08,
        "D": 0x02,
        "E": 0x0E,
        "F": 0x03,
        "G": 0x05,
        "H": 0x04,
        "I": 0x22,
        "J": 0x26,
        "K": 0x28,
        "L": 0x25,
        "M": 0x2E,
        "N": 0x2D,
        "O": 0x1F,
        "P": 0x23,
        "Q": 0x0C,
        "R": 0x0F,
        "S": 0x01,
        "T": 0x11,
        "U": 0x20,
        "V": 0x09,
        "W": 0x0D,
        "X": 0x07,
        "Y": 0x10,
        "Z": 0x06
    ]
    
    
    private init() {
        setupEventHandler()
        setupOptionKeyMonitor()
        setupAppSwitchObserver()
        
        // 监听设置变化
        NotificationCenter.default.addObserver(forName: NSNotification.Name("SettingsChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.handleSettingsChanged()
        }
    }
    
    deinit {
        unregisterAllHotKeys()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        if let monitor = localFlagsMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = optionKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupOptionKeyMonitor() {
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleModifierFlagsChanged(event)
            return event
        }
        
        optionKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleModifierFlagsChanged(event)
        }
    }

    private func handleModifierFlagsChanged(_ event: NSEvent) {
        updateOptionKeyTracking(with: event)
        handleLastAppSwitchTriggerEvent(with: event)

        let optionKeyPressed = activeOptionKeyCode != nil
        
        if optionKeyPressed != isOptionKeyPressed {
            isOptionKeyPressed = optionKeyPressed
        }
    }

    private func handleLastAppSwitchTriggerEvent(with event: NSEvent) {
        let selectedTrigger = AppSettings.shared.lastAppSwitchTrigger
        guard selectedTrigger != .disabled else {
            isSwitchTriggerKeyPressed = false
            resetOptionClickDetectionState()
            return
        }
        
        guard let triggerKeyPressed = triggerState(from: event, for: selectedTrigger) else {
            return
        }
        optiDebugLog("[HotKeyManager] 触发键事件: \(selectedTrigger.rawValue), keyCode=\(event.keyCode), pressed=\(triggerKeyPressed)")
        guard triggerKeyPressed != isSwitchTriggerKeyPressed else {
            return
        }
        
        isSwitchTriggerKeyPressed = triggerKeyPressed
        
        if triggerKeyPressed {
            let now = Date()
            let timeSinceLastRelease = now.timeIntervalSince(optionClickLastReleaseTime)
            optionClickLastPressTime = now
            
            if optionClickJustHandledDoubleClick {
                optiDebugLog("👆 重置双击处理标记")
                optionClickJustHandledDoubleClick = false
            }
            
            optionSingleClickTimer?.invalidate()
            optionSingleClickTimer = nil
            
            if timeSinceLastRelease < 0.5 {
                optionClickCount += 1
                optionClickPotentialDoubleClick = true
                optiDebugLog("⚡ 检测到可能的双击: 点击计数=\(optionClickCount)")
            } else {
                optionClickCount = 1
                optionClickPotentialDoubleClick = false
                optiDebugLog("👇 首次点击或距离上次释放时间较长")
            }
        } else {
            optionClickLastReleaseTime = Date()
            let pressDuration = optionClickLastReleaseTime.timeIntervalSince(optionClickLastPressTime)
            
            let isDoubleClick = optionClickCount >= 2 && pressDuration < 0.3
            if isDoubleClick {
                optionClickJustHandledDoubleClick = true
            }
            
            if pressDuration < 0.3 && !optionClickPotentialDoubleClick {
                optionSingleClickTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                    self.optionSingleClickTimer = nil
                    self.handleSingleClickSwitchToLastApp()
                }
            }
        }
    }

    private func triggerState(from event: NSEvent, for trigger: LastAppSwitchTrigger) -> Bool? {
        switch trigger {
        case .disabled:
            return false
        case .option:
            if let activeKeyCode = activeSwitchTriggerOptionKeyCode {
                guard isOptionKeyEvent(event), event.keyCode == activeKeyCode else {
                    return nil
                }

                activeSwitchTriggerOptionKeyCode = nil
                return false
            }

            guard isEnabledOptionKeyEvent(event), event.modifierFlags.contains(.option) else {
                return nil
            }

            activeSwitchTriggerOptionKeyCode = event.keyCode
            return true
        case .rightCommand:
            guard event.keyCode == rightCommandKeyCode else {
                return nil
            }
            return event.modifierFlags.contains(.command)
        }
    }

    private func currentState(for trigger: LastAppSwitchTrigger) -> Bool {
        switch trigger {
        case .disabled:
            return false
        case .option:
            return activeSwitchTriggerOptionKeyCode != nil
        case .rightCommand:
            return CGEventSource.keyState(.combinedSessionState, key: rightCommandKeyCode)
        }
    }

    private func isOptionKeyEvent(_ event: NSEvent) -> Bool {
        event.keyCode == leftOptionKeyCode || event.keyCode == rightOptionKeyCode
    }

    private func isEnabledOptionKeyEvent(_ event: NSEvent) -> Bool {
        switch AppSettings.shared.optionKeyActivationMode {
        case .leftOnly:
            return event.keyCode == leftOptionKeyCode
        case .rightOnly:
            return event.keyCode == rightOptionKeyCode
        case .both:
            return isOptionKeyEvent(event)
        }
    }

    private func updateOptionKeyTracking(with event: NSEvent) {
        guard isOptionKeyEvent(event) else {
            return
        }

        if let activeKeyCode = activeOptionKeyCode {
            if event.keyCode == activeKeyCode {
                activeOptionKeyCode = nil
            }
            return
        }

        guard isEnabledOptionKeyEvent(event), event.modifierFlags.contains(.option) else {
            return
        }

        activeOptionKeyCode = event.keyCode
    }

    private func handleSingleClickSwitchToLastApp() {
        guard AppSettings.shared.lastAppSwitchTrigger != .disabled else {
            optiDebugLog("⏭️ 单击检测：未启用应用切换功能")
            return
        }
        
        optiDebugLog("🔍 单击检测：处理应用切换")
        AppSettings.shared.incrementUsageCount(type: .optionClick)
        
        if let currentApp = NSWorkspace.shared.frontmostApplication {
            if let lastApp = lastActiveApp,
               lastApp.bundleIdentifier != currentApp.bundleIdentifier,
               lastApp.isTerminated == false {
                optiDebugLog("✅ 切换到上一个应用: \(lastApp.localizedName ?? ""), 从: \(currentApp.localizedName ?? "")")
                
                lastActiveApp = currentApp
                
                DispatchQueue.main.async {
                    self.switchToApp(bundleIdentifier: lastApp.bundleIdentifier ?? "")
                }
            } else {
                optiDebugLog("📝 记录当前应用: \(currentApp.localizedName ?? "")")
                lastActiveApp = currentApp
            }
        }
    }

    private func resetOptionClickDetectionState() {
        optionSingleClickTimer?.invalidate()
        optionSingleClickTimer = nil
        optionClickCount = 0
        optionClickPotentialDoubleClick = false
        optionClickJustHandledDoubleClick = false
        optionClickLastPressTime = Date.distantPast
        optionClickLastReleaseTime = Date.distantPast
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        
        let status = InstallEventHandler(
            GetEventMonitorTarget(),
            { (_, event, _) -> OSStatus in
                guard let event = event else { return OSStatus(eventNotHandledErr) }
                
                var hotkeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )
                
                if err == noErr {
                    HotKeyManager.shared.handleHotKey(hotkeyID.id)
                }
                
                return OSStatus(noErr)
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )
        
        if status == noErr {
            optiDebugLog("Event handler installed successfully")
            registerAllHotKeys()
        } else {
            optiDebugLog("Failed to install event handler: \(status)")
        }
    }
    
    private func registerAllHotKeys() {
        unregisterAllHotKeys()
        hotKeyRefs.removeAll()
        
        let appShortcuts = AppSettings.shared.shortcuts
        let websites = websiteManager.getWebsites()
        let configuredWebsiteKeys = websites.compactMap { $0.shortcutKey }
        
        // 创建热键映射表，用于调试
        var keyMappings: [Int: String] = [:]
        
        // 输出调试信息
        optiDebugLog("已配置的应用快捷键: \(appShortcuts.map { $0.key }.joined(separator: ", "))")
        optiDebugLog("已配置的网站快捷键: \(configuredWebsiteKeys.joined(separator: ", "))")
        
        // 获取所有已配置快捷键
        let configuredNumberKeys = appShortcuts.filter { Int($0.key) != nil }.map { $0.key }
        let configuredLetterKeys = appShortcuts.filter { Int($0.key) == nil }.map { $0.key }
        
        // 只注册用户配置了的数字键快捷键
        for i in 1...9 {
            let key = String(i)
            if configuredNumberKeys.contains(key) {
                let appId = i
                keyMappings[appId] = key
                registerHotKey(id: appId, keyCode: numberKeyCodes[i]!, isWebsite: false)
                optiDebugLog("注册应用快捷键: Option+\(key), ID: \(appId)")
            }
            // 只注册已配置的网站快捷键
            if configuredWebsiteKeys.contains(key) {
                let webId = i + 1000  // 使用更大的偏移值避免冲突
                keyMappings[webId] = key
                registerHotKey(id: webId, keyCode: numberKeyCodes[i]!, isWebsite: true)
                optiDebugLog("注册网站快捷键: Option+Command+\(key), ID: \(webId)")
            }
        }
        
        // 只注册用户配置了的字母键快捷键
        for (letter, keyCode) in letterKeyCodes {
            let asciiValue = Int(UnicodeScalar(letter)!.value)
            
            if configuredLetterKeys.contains(letter) {
                let appId = 100 + asciiValue  // 新的ID生成方式
                keyMappings[appId] = letter
                let registrationResult = registerHotKey(id: appId, keyCode: keyCode, isWebsite: false)
                optiDebugLog("注册应用快捷键: Option+\(letter), ID: \(appId) \(registrationResult ? "成功" : "失败")")
            }
            
            // 只注册已配置的网站快捷键
            if configuredWebsiteKeys.contains(letter) {
                let webId = 1000 + asciiValue  // 使用更大的偏移值避免冲突
                keyMappings[webId] = letter
                let registrationResult = registerHotKey(id: webId, keyCode: keyCode, isWebsite: true)
                optiDebugLog("注册网站快捷键: Option+Command+\(letter), ID: \(webId) \(registrationResult ? "成功" : "失败")")
            }
        }
        
        // 保存热键映射表，用于调试
        self.keyMappings = keyMappings
        
        optiDebugLog("已注册 \(hotKeyRefs.count) 个快捷键")
    }
    
    // 热键映射表，用于调试
    private var keyMappings: [Int: String] = [:]
    
    @discardableResult
    private func registerHotKey(id: Int, keyCode: Int, isWebsite: Bool) -> Bool {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(id)
        hotKeyID.id = UInt32(id)
        
        var hotKeyRef: EventHotKeyRef?
        
        let modifiers: UInt32 = isWebsite ? UInt32(optionKey | cmdKey) : UInt32(optionKey)
        
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            modifiers,
            hotKeyID,
            GetEventMonitorTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr {
            hotKeyRefs.append(hotKeyRef)
            optiDebugLog("Successfully registered hotkey for ID \(id)")
            return true
        } else {
            optiDebugLog("Failed to register hotkey for ID \(id), error: \(status)")
            return false
        }
    }
    
    private func unregisterAllHotKeys() {
        for hotKeyRef in hotKeyRefs {
            if let ref = hotKeyRef {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
    }
    
    private func handleHotKey(_ id: UInt32) {
        // RegisterEventHotKey only invokes this handler for a registered Option chord.
        // Do not gate it on the asynchronous NSEvent flagsChanged monitor: on
        // macOS 27 an Option-only chord can arrive before that state is updated.
        let number = Int(id)
        
        // 使用映射表直接获取键，避免复杂的计算
        guard let key = keyMappings[number] else {
            optiDebugLog("错误: 未找到ID \(number) 对应的热键")
            return
        }
        
        // 基于ID范围判断是否为网站快捷键
        let isWebsite = number >= 1000
        
        DispatchQueue.main.async {
            optiDebugLog("触发热键 ID: \(id), 键: \(key), 是否网站: \(isWebsite)")
            
            // 增加使用次数
            AppSettings.shared.incrementUsageCount(type: .shortcut)
            
            if isWebsite {
                // 处理网站快捷键
                let websites = self.websiteManager.getWebsites()
                if let website = websites.first(where: { $0.shortcutKey == key }) {
                    optiDebugLog("打开网站: \(website.displayName), URL: \(website.url)")
                    if let url = URL(string: website.url) {
                        NSWorkspace.shared.open(url)
                    }
                    optiDebugLog("[HotKeyManager] 快捷键触发: 成功打开网站 \(website.displayName)")
                    
                    return
                } else {
                    optiDebugLog("未找到快捷键为 \(key) 的网站")
                }
            } else {
                // 处理应用快捷键
                if let shortcut = AppSettings.shared.shortcuts.first(where: { $0.key == key }) {
                    optiDebugLog("Found shortcut for key \(key): \(shortcut.appName)")
                    
                    // 检查当前活跃的应用是否是目标应用
                    if let currentApp = NSWorkspace.shared.frontmostApplication,
                       currentApp.bundleIdentifier == shortcut.bundleIdentifier {
                        if self.shouldReopenWindowlessApp(bundleIdentifier: shortcut.bundleIdentifier),
                           !self.hasVisibleWindow(for: currentApp) {
                            self.switchToApp(bundleIdentifier: shortcut.bundleIdentifier)
                            optiDebugLog("[HotKeyManager] 目标应用在前台但无可见窗口，重新打开: \(shortcut.appName)")
                            return
                        }

                        // 如果是，则切换回上一个应用
                        if let lastApp = self.lastActiveApp {
                            optiDebugLog("Switching back to previous app: \(lastApp.localizedName ?? "")")
                            self.switchToApp(bundleIdentifier: lastApp.bundleIdentifier ?? "")
                        }
                    } else {
                        // 如果不是，则记录当前应用并切换到目标应用
                        self.lastActiveApp = NSWorkspace.shared.frontmostApplication
                        self.switchToApp(bundleIdentifier: shortcut.bundleIdentifier)
                    }
                    optiDebugLog("[HotKeyManager] 全局快捷键触发: 成功启动应用 \(shortcut.appName)")
                    
                    return
                } else {
                    optiDebugLog("No shortcut found for key \(key)")
                }
            }
        }
    }
    
    func switchToApp(bundleIdentifier: String) {
        optiDebugLog("Attempting to switch to app with bundle ID: \(bundleIdentifier)")

        guard !bundleIdentifier.isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            optiDebugLog("Could not find app with bundle ID: \(bundleIdentifier)")
            return
        }

        // 让 Launch Services 复用已运行实例并将其带到前台。
        // 这条路径同时适用于已运行和未运行的应用，并避开已废弃的
        // NSApplication.ActivationOptions.activateIgnoringOtherApps。
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            if let error = error {
                optiDebugLog("Error opening app \(bundleIdentifier): \(error)")
                return
            }

            optiDebugLog("Opened app \(app?.localizedName ?? bundleIdentifier) at \(url)")
        }
    }

    private func hasVisibleWindow(for app: NSRunningApplication) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        return windows.contains { window in
            guard let ownerPID = (window[kCGWindowOwnerPID as String] as? NSNumber)?.intValue,
                  let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue else {
                return false
            }
            return ownerPID == Int(app.processIdentifier) && layer == 0
        }
    }

    private func shouldReopenWindowlessApp(bundleIdentifier: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
              let bundle = Bundle(url: url) else {
            return false
        }

        let isUIElement = bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool ?? false
        let isBackgroundOnly = bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool ?? false
        return !isUIElement && !isBackgroundOnly
    }

    func updateShortcuts() {
        registerAllHotKeys()
        // 触发观察者更新
        lastUpdateTime = Date()
    }
    
    // 添加应用切换观察者
    private func setupAppSwitchObserver() {
        // 初始化当前应用
        currentApp = NSWorkspace.shared.frontmostApplication
        
        // 监听应用切换事件
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // 获取新激活的应用
            if let newApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                // 仅当通过非Option键切换应用时更新lastActiveApp
                if !self.isOptionKeyPressed && !self.isSwitchTriggerKeyPressed && self.currentApp != nil {
                    // 将当前应用设为上一个应用
                    self.lastActiveApp = self.currentApp
                    optiDebugLog("应用切换: \(self.currentApp?.localizedName ?? "未知") -> \(newApp.localizedName ?? "未知")")
                }
                
                // 更新当前应用
                self.currentApp = newApp
            }
        }
    }
    
    
    // 提供一个方法让其他类访问上一个活跃应用
    func getLastActiveApp() -> NSRunningApplication? {
        return lastActiveApp
    }
    
    
    // 处理设置变化
    private func handleSettingsChanged() {
        if AppSettings.shared.lastAppSwitchTrigger == .disabled {
            isSwitchTriggerKeyPressed = false
            activeSwitchTriggerOptionKeyCode = nil
            resetOptionClickDetectionState()
            return
        }
        
        isSwitchTriggerKeyPressed = currentState(
            for: AppSettings.shared.lastAppSwitchTrigger
        )
    }
}
