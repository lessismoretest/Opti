import Foundation
import SwiftUI
import AppKit

/**
 * 圆环模式控制器
 * 负责处理圆环模式的显示、隐藏和交互
 */
class CircleRingController: ObservableObject {
    enum ContentMode {
        case apps
        case websites
    }

    static let shared = CircleRingController()
    private let leftOptionKeyCode: CGKeyCode = 58
    private let rightOptionKeyCode: CGKeyCode = 61
    
    // 圆环窗口
    private var window: NSWindow?
    
    // 圆环是否可见
    @Published var isVisible = false
    
    // 图标动画是否完成
    @Published var iconsAnimationCompleted = false
    
    // 监听Option键的本地监视器
    private var localEventMonitor: Any?
    
    // 监听Option键的全局监视器
    private var globalEventMonitor: Any?
    
    // 保存鼠标位置
    private var currentMouseLocation: NSPoint = .zero
    
    // 圆环固定位置（显示后不再跟随鼠标）
    private var fixedRingPosition: NSPoint = .zero
    
    // 记录Option键按下的时间，用于区分长按和点击
    private var optionKeyPressTime: Date?
    
    // 长按判定时间（秒）- 从设置获取
    private var longPressThreshold: TimeInterval {
        return TimeInterval(AppSettings.shared.circleRingLongPressThreshold)
    }
    
    // 定时器，用于延迟显示圆环
    private var longPressTimer: Timer?
    
    // 是否正在调试
    private var isDebugging = false
    
    // 发布被选中的应用索引
    @Published var selectedAppIndex: Int? = nil

    // 记录上一次观察到的 Option 状态，避免重复处理同一 flagsChanged
    private var lastObservedOptionState = false
    private var activeOptionKeyCode: CGKeyCode?
    
    // 添加设置引用
    private var settings: AppSettings {
        return AppSettings.shared
    }

    @Published private(set) var contentMode: ContentMode = .apps
    @Published private(set) var activeSessionContentMode: ContentMode = .apps
    
    private init() {
        isDebugging = ProcessInfo.processInfo.environment["DEBUG"] == "1"
        setupEventMonitors()
        
        // 添加屏幕配置变化通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenConfigurationChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        // 在调试模式下打印日志
        optiDebugLog("[CircleRingController] 初始化完成")
    }
    
    deinit {
        removeEventMonitors()
        cancelLongPressTimer()
        
        // 移除屏幕配置变化通知监听
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    // 设置事件监听器
    private func setupEventMonitors() {
        // 本地事件监听器保留为空，避免与全局监听重复处理同一 flagsChanged 事件
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            event
        }
        
        // 全局事件监听器 - 跟踪鼠标位置和键盘事件
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .flagsChanged]) { [weak self] event in
            if event.type == .mouseMoved {
                self?.currentMouseLocation = NSEvent.mouseLocation
                // 只在圆环不可见时更新位置，避免圆环跟随鼠标
                if self?.isVisible == false {
                    self?.updateCurrentMousePosition()
                }
            } else if event.type == .leftMouseDown && self?.isVisible == true {
                // 如果圆环可见且用户点击，则处理点击事件
                self?.handleMouseClick()
            } else if event.type == .flagsChanged {
                // 在全局环境中也处理Option键事件
                self?.handleKeyEvent(event)
            }
        }
        
        if isDebugging {
            optiDebugLog("[CircleRingController] 事件监听器设置完成")
        }
    }
    
    // 更新当前鼠标位置（不更新圆环位置）
    private func updateCurrentMousePosition() {
        if isDebugging && isVisible == false {
            optiDebugLog("[CircleRingController] 更新当前鼠标位置: \(currentMouseLocation)")
        }
    }
    
    // 移除事件监听器
    private func removeEventMonitors() {
        if let localMonitor = localEventMonitor {
            NSEvent.removeMonitor(localMonitor)
            localEventMonitor = nil
        }
        
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
            globalEventMonitor = nil
        }
    }
    
    // 处理键盘事件
    private func handleKeyEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            // 检查已启用的 Option 键是否按下或释放
            let isOptionKeyDown: Bool
            let isCommandKeyDown = event.modifierFlags.contains(.command)

            if let activeKeyCode = activeOptionKeyCode {
                if isOptionKeyEvent(event), event.keyCode == activeKeyCode {
                    activeOptionKeyCode = nil
                    isOptionKeyDown = false
                } else {
                    isOptionKeyDown = true
                }
            } else {
                guard isEnabledOptionKeyEvent(event), event.modifierFlags.contains(.option) else {
                    return
                }

                activeOptionKeyCode = event.keyCode
                isOptionKeyDown = true
            }

            guard isOptionKeyDown != lastObservedOptionState else {
                if isOptionKeyDown {
                    updateContentModeWhileOptionHeld(isCommandKeyDown: isCommandKeyDown)
                }
                return
            }

            lastObservedOptionState = isOptionKeyDown

            if isOptionKeyDown {
                updateContentModeWhileOptionHeld(isCommandKeyDown: isCommandKeyDown)
            }
            
            if isDebugging {
                optiDebugLog("[CircleRingController] Option键状态: \(isOptionKeyDown ? "按下" : "释放"), 当前时间: \(Date())")
            }
            
            if isOptionKeyDown && optionKeyPressTime == nil {
                // Option键被按下，记录时间和当前鼠标位置
                optionKeyPressTime = Date()
                currentMouseLocation = NSEvent.mouseLocation
                
                if isDebugging {
                    optiDebugLog("[CircleRingController] Option键按下时间记录: \(optionKeyPressTime!), 鼠标位置: \(currentMouseLocation)")
                }
                
                // 设置定时器，延迟显示圆环，避免与快速点击冲突
                cancelLongPressTimer()
                longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressThreshold, repeats: false) { [weak self] timer in
                    guard let self = self else { return }
                    
                    if let pressTime = self.optionKeyPressTime {
                        let pressDuration = Date().timeIntervalSince(pressTime)
                        
                        if self.isDebugging {
                            optiDebugLog("[CircleRingController] 定时器触发，按下时长: \(pressDuration)秒")
                        }
                        
                        if pressDuration >= self.longPressThreshold {
                            // 长按阈值时间后显示圆环
                            self.fixedRingPosition = self.currentMouseLocation // 固定圆环位置
                            self.showCircleRing()
                        }
                    }
                }
                
                if isDebugging {
                    optiDebugLog("[CircleRingController] 长按定时器已设置")
                }
            } else if !isOptionKeyDown {
                // Option键被释放
                cancelLongPressTimer()
                
                if let pressTime = optionKeyPressTime {
                    let pressDuration = Date().timeIntervalSince(pressTime)
                    
                    if isDebugging {
                        optiDebugLog("[CircleRingController] Option键释放，按下时长: \(pressDuration)秒")
                    }
                    
                    if isVisible {
                        // 如果圆环可见，处理选择
                        handleOptionKeyRelease()
                        
                        if isDebugging {
                            optiDebugLog("[CircleRingController] 处理Option键释放 (圆环可见)")
                        }
                    } else if pressDuration < longPressThreshold {
                        // 短按不做任何事，让系统处理默认行为（如切换上一个应用）
                        if isDebugging {
                            optiDebugLog("[CircleRingController] 短按Option键，不处理")
                        }
                    }
                }
                
                // 重置按下时间
                optionKeyPressTime = nil
            }
        }
    }
    
    // 取消长按定时器
    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        
        if isDebugging {
            optiDebugLog("[CircleRingController] 长按定时器已取消")
        }
    }
    
    // 处理Option键释放事件
    private func handleOptionKeyRelease() {
        if isVisible {
            optiDebugLog("[CircleRingController] Option 键释放，当前鼠标位置: \(currentMouseLocation)")
            
            // 如果图标动画还未完成，等待动画完成再处理，但减少等待时间
            if settings.useCircleRingAnimation && settings.useIconAppearAnimation && !iconsAnimationCompleted {
                optiDebugLog("[CircleRingController] 图标动画未完成，等待...")
                
                // 减少等待时间从0.5秒到0.25秒
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                    guard let self = self else { return }
                    self.iconsAnimationCompleted = true
                    self.processOptionKeyRelease()
                }
                return
            }
            
            // 正常处理Option键释放
            processOptionKeyRelease()
        }
        
        // 重置状态
        optionKeyPressTime = nil
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
    
    // 处理Option键释放实际逻辑
    private func processOptionKeyRelease() {
        // 在释放Option键时，先修正最后的鼠标位置，然后再处理选择
        ensureCorrectMousePosition()
        
        // 减少延迟时间，从0.2秒到0.1秒，确保鼠标位置被更新到正确扇区
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // 直接尝试使用已选择的应用索引启动应用
            if let selectedIndex = self.selectedAppIndex, 
               selectedIndex >= 0, 
               selectedIndex < self.selectedItemsCount {

                if self.activeSessionContentMode == .websites {
                    let websites = WebsiteManager.shared.getWebsites()
                    if selectedIndex < AppSettings.shared.circleRingWebsites.count {
                        let websiteIdString = AppSettings.shared.circleRingWebsites[selectedIndex]
                        guard let websiteId = UUID(uuidString: websiteIdString) else {
                            self.hideCircleRing()
                            return
                        }
                        if let website = websites.first(where: { $0.id == websiteId }),
                           let url = URL(string: website.url) {
                            optiDebugLog("[CircleRingController] 直接使用选中的索引打开网站: \(website.url), 索引: \(selectedIndex)")
                            NSWorkspace.shared.open(url)
                            AppSettings.shared.incrementUsageCount(type: .circleRing)
                            self.hideCircleRing()
                            return
                        }
                    }
                }

                let bundleId = AppSettings.shared.circleRingApps[selectedIndex]
                optiDebugLog("[CircleRingController] 直接使用选中的索引启动应用: \(bundleId), 索引: \(selectedIndex)")
                
                // 检查选中的应用是否为当前前台应用
                if let currentApp = NSWorkspace.shared.frontmostApplication,
                   currentApp.bundleIdentifier == bundleId {
                    // 检查是否启用了点击当前应用切换回上一个应用的功能
                    if AppSettings.shared.clickCircleAppToToggle {
                        // 如果是当前前台应用，则切换到上一个应用
                        optiDebugLog("[CircleRingController] 选中的应用是当前前台应用，尝试切换到上一个应用")
                        
                        // 使用HotKeyManager切换到上一个应用
                        if let lastApp = HotKeyManager.shared.getLastActiveApp(),
                           lastApp.bundleIdentifier != currentApp.bundleIdentifier,
                           !lastApp.isTerminated {
                            
                            optiDebugLog("[CircleRingController] 切换到上一个应用: \(lastApp.localizedName ?? "")")
                            
                            // 增加使用计数
                            AppSettings.shared.incrementUsageCount(type: .circleRing)
                            
                            // 隐藏圆环
                            self.hideCircleRing()
                            
                            // 切换到上一个应用
                            DispatchQueue.main.async {
                                HotKeyManager.shared.switchToApp(bundleIdentifier: lastApp.bundleIdentifier ?? "")
                            }
                            return
                        } else {
                            optiDebugLog("[CircleRingController] 无法获取上一个应用或上一个应用已终止")
                        }
                    }
                }
                
                // 尝试启动应用
                if NSWorkspace.shared.launchApplication(withBundleIdentifier: bundleId, 
                                                       options: [.default], 
                                                       additionalEventParamDescriptor: nil, 
                                                       launchIdentifier: nil) {
                    optiDebugLog("[CircleRingController] 成功启动应用: \(bundleId)")
                    
                    // 增加使用计数
                    AppSettings.shared.incrementUsageCount(type: .circleRing)
                    
                    // 隐藏圆环
                    self.hideCircleRing()
                    return
                } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
                    // 如果直接启动失败，尝试使用URL打开
                    NSWorkspace.shared.open(url)
                    optiDebugLog("[CircleRingController] 通过URL启动应用: \(bundleId)")
                    
                    // 增加使用计数
                    AppSettings.shared.incrementUsageCount(type: .circleRing)
                    
                    // 隐藏圆环
                    self.hideCircleRing()
                    return
                } else {
                    optiDebugLog("[CircleRingController] 无法启动应用: \(bundleId)")
                }
            } else {
                // 备用方法：尝试从HostingView获取CircleRingView
                if let circleRingWindow = self.window,
                   let contentView = circleRingWindow.contentView {
                    
                    // 递归函数查找视图
                    func findCircleRingViewIn(view: NSView) -> Bool {
                        // 检查视图的类型
                        if let hostingView = view as? NSHostingView<CircleRingView> {
                            optiDebugLog("[CircleRingController] 递归方式找到 HostingView")
                            
                            // 直接访问rootView属性(不是可选类型)
                            let circleRingView = hostingView.rootView
                            optiDebugLog("[CircleRingController] 递归方式成功获取 CircleRingView")
                            
                            // 获取选中的应用
                            if let selectedApp = circleRingView.getSelectedApp() {
                                // 启动选中的应用
                                circleRingView.launchApp(selectedApp)
                                optiDebugLog("[CircleRingController] 启动应用: \(selectedApp.name)")
                                return true
                            }
                        }
                        
                        // 递归检查所有子视图
                        for subview in view.subviews {
                            if findCircleRingViewIn(view: subview) {
                                return true
                            }
                        }
                        
                        return false
                    }
                    
                    // 从contentView开始递归查找
                    if findCircleRingViewIn(view: contentView) {
                        optiDebugLog("[CircleRingController] 使用递归方法成功找到并处理了CircleRingView")
                        self.hideCircleRing()
                        return
                    }
                }
                
                optiDebugLog("[CircleRingController] 没有选中任何扇区或无法找到视图，结束操作")
            }
            
            // 隐藏圆环
            self.hideCircleRing()
        }
    }

    private var selectedItemsCount: Int {
        switch activeSessionContentMode {
        case .apps:
            return AppSettings.shared.circleRingApps.count
        case .websites:
            return AppSettings.shared.circleRingWebsites.count
        }
    }

    private func updateContentMode(_ newMode: ContentMode) {
        guard contentMode != newMode || (isVisible && activeSessionContentMode != newMode) else {
            return
        }

        contentMode = newMode

        if isVisible {
            activeSessionContentMode = newMode
            selectedAppIndex = nil
        }
    }

    private func updateContentModeWhileOptionHeld(isCommandKeyDown: Bool) {
        if !isVisible {
            updateContentMode(isCommandKeyDown ? .websites : .apps)
            return
        }

        // 圆环已经显示后，允许从应用切到网站，
        // 但不要因为先松 Command 又把当前会话切回应用，
        // 否则最终松 Option 时会按错误模式打开。
        if isCommandKeyDown && activeSessionContentMode == .apps {
            updateContentMode(.websites)
        }
    }

    // 处理鼠标点击
    private func handleMouseClick() {
        // 隐藏圆环
        hideCircleRing()
        
        if isDebugging {
            optiDebugLog("[CircleRingController] 处理鼠标点击，隐藏圆环")
        }
    }
    
    // 显示圆环
    func showCircleRing() {
        // 确保圆环模式启用
        if !isVisible && !AppSettings.shared.enableCircleRingMode {
            optiDebugLog("[CircleRingController] 无法显示圆环: isVisible=\(isVisible), enableCircleRingMode=\(AppSettings.shared.enableCircleRingMode)")
            return
        }

        // 获取当前鼠标位置的屏幕
        let mouseLocation = NSEvent.mouseLocation

        // 安全区域检查：鼠标距离屏幕边缘太近时不显示圆环
        let safeZoneMargin = AppSettings.shared.circleRingSafeZoneMargin
        if safeZoneMargin > 0,
           let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) {
            let frame = screen.frame
            let distanceToLeft   = mouseLocation.x - frame.minX
            let distanceToRight  = frame.maxX - mouseLocation.x
            let distanceToBottom = mouseLocation.y - frame.minY
            let distanceToTop    = frame.maxY - mouseLocation.y
            let minDistance = min(distanceToLeft, distanceToRight, distanceToBottom, distanceToTop)
            if minDistance < safeZoneMargin {
                optiDebugLog("[CircleRingController] 安全区域限制，鼠标距边缘 \(minDistance)px < \(safeZoneMargin)px，不显示圆环")
                return
            }
        }

        // 记录长按使用统计
        AppSettings.shared.incrementUsageCount(type: .optionLongPress)
        activeSessionContentMode = contentMode
        let currentScreen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) ?? NSScreen.main
        
        if isDebugging, let screen = currentScreen {
            optiDebugLog("[CircleRingController] 当前鼠标位置的屏幕: \(screen.localizedName ?? "未知"), 可见区域: \(screen.visibleFrame)")
        }
        
        // 如果悬浮窗可见，确保圆环窗口在悬浮窗之上
        let floatingWindowVisible = NSApp.windows.contains(where: { $0.isVisible && $0.level == .floating })
        if floatingWindowVisible {
            optiDebugLog("[CircleRingController] 检测到悬浮窗可见，将调整圆环窗口层级")
        }
        
        // 如果窗口不存在，创建一个新窗口
        if window == nil {
            createCircleRingWindow()
            optiDebugLog("[CircleRingController] 创建圆环窗口")
        }
        
        // 使用当前鼠标位置更新圆环位置 - 这将应用屏幕边界检查
        currentMouseLocation = mouseLocation
        updateCircleRingPosition()
        
        // 显示窗口
        window?.orderFront(nil)
        isVisible = true
        
        // 添加事件监听器以实时追踪鼠标位置
        NotificationCenter.default.addObserver(self, selector: #selector(trackMouseMovement), name: NSWindow.didMoveNotification, object: nil)
        
        // 发送圆环显示通知，触发展开动画
        NotificationCenter.default.post(name: NSNotification.Name("CircleRingDidAppear"), object: nil)
        
        // 显示圆环后立即发送鼠标事件触发扇区检测 - 减少延迟从0.05秒到0.03秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            // 获取窗口大小和位置
            let windowOrigin = window.frame.origin
            let windowSize = window.frame.size
            
            // 获取当前鼠标位置
            let mouseLocation = NSEvent.mouseLocation
            let relativeX = mouseLocation.x - windowOrigin.x
            let relativeY = mouseLocation.y - windowOrigin.y
            
            // 创建模拟鼠标移动事件 - 直接发送到实际鼠标位置
            if let mouseEvent = NSEvent.mouseEvent(
                with: .mouseMoved,
                location: NSPoint(x: relativeX, y: relativeY),
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            ) {
                window.sendEvent(mouseEvent)
                optiDebugLog("[CircleRingController] 圆环已显示，发送初始鼠标事件: (\(relativeX), \(relativeY))")
            }
            
            // 发送通知强制更新鼠标位置
            NotificationCenter.default.post(name: NSNotification.Name("ForceUpdateMousePosition"), object: nil)
            
            // 确保鼠标继续被追踪
            startMouseTracking()
        }
        
        optiDebugLog("[CircleRingController] 圆环已显示")
    }
    
    // 开始追踪鼠标移动 - 减少延迟从0.08秒到0.05秒
    private func startMouseTracking() {
        guard isVisible, let window = self.window else { return }
        
        // 定期更新鼠标位置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self, self.isVisible, let window = self.window else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            let windowOrigin = window.frame.origin
            let windowSize = window.frame.size
            
            // 计算相对位置
            let relativeX = mouseLocation.x - windowOrigin.x
            let relativeY = mouseLocation.y - windowOrigin.y
            
            // 创建鼠标移动事件
            if let mouseEvent = NSEvent.mouseEvent(
                with: .mouseMoved,
                location: NSPoint(x: relativeX, y: relativeY),
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            ) {
                window.sendEvent(mouseEvent)
                optiDebugLog("[CircleRingController] 发送鼠标追踪事件: (\(relativeX), \(relativeY))")
            }
            
            // 发送通知强制更新鼠标位置
            NotificationCenter.default.post(name: NSNotification.Name("ForceUpdateMousePosition"), object: nil)
            
            // 继续追踪如果圆环仍然可见
            if self.isVisible {
                self.startMouseTracking()
            }
        }
    }
    
    // 跟踪鼠标移动的通知处理方法
    @objc private func trackMouseMovement() {
        guard isVisible, let window = self.window else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let windowOrigin = window.frame.origin
        let windowSize = window.frame.size
        
        // 计算鼠标相对于窗口的位置
        let relativeX = mouseLocation.x - windowOrigin.x
        let relativeY = mouseLocation.y - windowOrigin.y
        
        // 创建鼠标移动事件
        if let mouseEvent = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: NSPoint(x: relativeX, y: relativeY),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        ) {
            window.sendEvent(mouseEvent)
        }
    }
    
    // 隐藏圆环
    func hideCircleRing() {
        guard isVisible else { return }
        
        // 移除通知监听器
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: nil)
        
        window?.orderOut(nil)
        isVisible = false
        iconsAnimationCompleted = false
        contentMode = .apps
        activeSessionContentMode = .apps
        
        if isDebugging {
            optiDebugLog("[CircleRingController] 圆环已隐藏")
        }
    }

    // 在切应用或重建窗口前重置瞬时按键状态，避免遗留的 Option 按下态导致闪烁
    func resetTransientState() {
        cancelLongPressTimer()
        optionKeyPressTime = nil
        activeOptionKeyCode = nil
        lastObservedOptionState = false
        selectedAppIndex = nil
        iconsAnimationCompleted = false
        activeSessionContentMode = isVisible ? contentMode : .apps
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
    
    // 创建圆环窗口
    private func createCircleRingWindow() {
        let settings = AppSettings.shared
        let size = settings.circleRingDiameter
        
        optiDebugLog("[CircleRingController] 开始创建圆环窗口，直径：\(size)")
        
        // 创建圆环视图
        let circleRingView = CircleRingView()
        
        // 创建主机视图
        let hostingView = NSHostingView(rootView: circleRingView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = CGColor.clear
        
        // 创建一个完全无边框的窗口
        let contentRect = NSRect(x: 0, y: 0, width: size, height: size)
        let window = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 设置窗口属性
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        window.level = .popUpMenu + 2  // 设置为更高层级，确保在悬浮窗之上
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = false
        
        // 只有在不使用自定义动画时才使用系统动画行为
        if !settings.useCircleRingAnimation {
            window.animationBehavior = .utilityWindow
        } else {
            window.animationBehavior = .none  // 禁用系统动画，使用自定义的展开动画
        }
        
        // 设置窗口为完全透明，以便能够看到下方窗口内容
        window.alphaValue = 1.0
        window.isOneShot = false
        
        // 创建透明的背景视图
        let transparentView = NSView()
        transparentView.wantsLayer = true
        transparentView.layer?.backgroundColor = CGColor.clear
        
        // 设置内容视图为透明视图
        window.contentView = transparentView
        
        // 将hostingView添加到透明视图上
        transparentView.addSubview(hostingView)
        hostingView.frame = transparentView.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        // 设置窗口形状为圆形
        if let layer = window.contentView?.superview?.layer {
            layer.backgroundColor = CGColor.clear
            
            // 创建圆形遮罩
            let maskLayer = CAShapeLayer()
            let path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: size, height: size), transform: nil)
            maskLayer.path = path
            
            // 将遮罩应用到窗口的最外层
            layer.mask = maskLayer
        }
        
        self.window = window
        
        // 确保视图已经完全加载后再触发鼠标事件 - 减少延迟时间从0.2秒到0.1秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            // 获取鼠标在窗口中的相对位置
            let mouseLocation = NSEvent.mouseLocation
            let windowOrigin = window.frame.origin
            let windowSize = window.frame.size
            
            // 计算鼠标相对于窗口的位置 - macOS坐标系原点在左下角
            let relativeX = mouseLocation.x - windowOrigin.x
            let relativeY = windowSize.height - (mouseLocation.y - windowOrigin.y)
            
            // 首先发送中心点事件，确保视图初始化
            let centerPoint = NSPoint(
                x: windowSize.width / 2,
                y: windowSize.height / 2
            )
            
            // 创建中心点鼠标事件
            if let centerEvent = NSEvent.mouseEvent(
                with: .mouseMoved,
                location: centerPoint,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber,
                context: nil,
                eventNumber: 0,
                clickCount: 0,
                pressure: 0
            ) {
                window.sendEvent(centerEvent)
                optiDebugLog("[CircleRingController] 已发送窗口中心点事件: \(centerPoint)")
            }
            
            // 短暂延迟后再发送实际鼠标位置事件
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // 再次获取并计算鼠标位置，以获取最新位置
                let currentMouseLocation = NSEvent.mouseLocation
                let currentRelativeX = currentMouseLocation.x - windowOrigin.x
                let currentRelativeY = windowSize.height - (currentMouseLocation.y - windowOrigin.y)
                
                let currentPosition = NSPoint(x: currentRelativeX, y: currentRelativeY)
                
                if let moveEvent = NSEvent.mouseEvent(
                    with: .mouseMoved,
                    location: currentPosition,
                    modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: 0,
                    pressure: 0
                ) {
                    window.sendEvent(moveEvent)
                    optiDebugLog("[CircleRingController] 已发送实际鼠标位置事件: \(currentPosition)")
                }
            }
        }
        
        optiDebugLog("[CircleRingController] 圆环窗口创建完成")
    }
    
    // 更新圆环位置
    private func updateCircleRingPosition() {
        guard let window = self.window else { return }
        
        let windowSize = window.frame.size
        
        // 使用固定位置或当前鼠标位置
        let mouseLocation = isVisible ? fixedRingPosition : currentMouseLocation
        
        // 计算窗口位置，使圆环中心位于鼠标位置
        var windowX = mouseLocation.x - windowSize.width / 2
        var windowY = mouseLocation.y - windowSize.height / 2
        
        // 获取当前屏幕边界
        if let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            
            // 确保窗口完全在屏幕边界内
            windowX = max(screenFrame.minX, min(windowX, screenFrame.maxX - windowSize.width))
            windowY = max(screenFrame.minY, min(windowY, screenFrame.maxY - windowSize.height))
            
            // 记录调整后的位置
            fixedRingPosition = NSPoint(x: windowX + windowSize.width / 2, y: windowY + windowSize.height / 2)
            
            if isDebugging {
                optiDebugLog("[CircleRingController] 屏幕边界检查: 原始位置 x=\(mouseLocation.x - windowSize.width / 2), y=\(mouseLocation.y - windowSize.height / 2), 调整后 x=\(windowX), y=\(windowY)")
            }
        }
        
        window.setFrameOrigin(NSPoint(x: windowX, y: windowY))
        
        if isDebugging {
            optiDebugLog("[CircleRingController] 更新圆环位置: x=\(windowX), y=\(windowY), 鼠标位置: \(mouseLocation)")
        }
    }
    
    // 重新加载圆环
    func reloadCircleRing() {
        optiDebugLog("[CircleRingController] 开始重新加载圆环")
        
        // 重置图标动画状态
        iconsAnimationCompleted = false
        
        // 如果正在显示，先隐藏再重新创建
        if isVisible {
            hideCircleRing()
            window = nil
            
            // 短暂延迟以确保视图完全更新 - 维持0.1秒
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                
                self.showCircleRing()
                optiDebugLog("[CircleRingController] 重新加载圆环完成 (可见状态)")
            }
        } else {
            // 否则只需要释放窗口资源
            window = nil
            optiDebugLog("[CircleRingController] 重新加载圆环完成 (隐藏状态)")
        }
    }
    
    // 调试方法: 强制显示圆环
    func debugShowCircleRing() {
        optiDebugLog("[CircleRingController] 调试强制显示圆环")
        // 先设置固定位置为当前鼠标位置
        fixedRingPosition = NSEvent.mouseLocation
        
        // 重置动画状态
        iconsAnimationCompleted = false
        
        // 然后显示圆环
        window = nil
        showCircleRing()
    }
    
    // 强制刷新扇区悬停效果
    func resetSectorHover() {
        if isVisible, let window = self.window {
            optiDebugLog("[CircleRingController] 强制刷新扇区悬停效果")
            
            // 使用简化版本的实现，避免闪烁
            quickResetSectorHover()
        } else {
            optiDebugLog("[CircleRingController] 无法重置扇区悬停效果：圆环未显示或视图不可用")
        }
    }
    
    // 更新长按阈值
    func updateLongPressThreshold() {
        optiDebugLog("[CircleRingController] 更新长按阈值为: \(AppSettings.shared.circleRingLongPressThreshold)秒")
        cancelLongPressTimer()
    }
    
    // 确保鼠标位置正确发送到圆环视图
    private func ensureCorrectMousePosition() {
        guard isVisible, let window = self.window else { return }
        
        // 获取鼠标位置和窗口位置
        let mouseLocation = NSEvent.mouseLocation
        let windowOrigin = window.frame.origin
        let windowSize = window.frame.size
        
        // 计算相对位置（鼠标相对于窗口的位置）
        let relativeX = mouseLocation.x - windowOrigin.x
        let relativeY = mouseLocation.y - windowOrigin.y
        
        // 确保窗口是否为前台窗口，如果不是则强制前置
        let isKeyWindow = window.isKeyWindow
        let isMainWindow = window.isMainWindow
        
        if !isKeyWindow || !isMainWindow {
            // 先尝试恢复焦点
            window.orderFront(nil)
            
            // 提高窗口层级以确保位于悬浮窗之上
            window.level = .popUpMenu + 2
            
            optiDebugLog("[CircleRingController] ensureCorrectMousePosition: 调整窗口层级, isKeyWindow=\(isKeyWindow), isMainWindow=\(isMainWindow)")
        }
        
        // 发送鼠标移动事件
        if let mouseEvent = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: NSPoint(x: relativeX, y: relativeY),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0
        ) {
            window.sendEvent(mouseEvent)
            if isDebugging {
                optiDebugLog("[CircleRingController] 发送修正的鼠标位置事件: (\(relativeX), \(relativeY))")
            }
        }
        
        // 发送强制更新位置通知 - 减少延迟从0.05秒到0.03秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            NotificationCenter.default.post(name: NSNotification.Name("ForceUpdateMousePosition"), object: nil)
        }
    }
    
    // 直接刷新扇区悬停效果的简化版本
    func quickResetSectorHover() {
        ensureCorrectMousePosition()
    }
    
    // 处理屏幕配置变化
    @objc private func handleScreenConfigurationChange() {
        if isVisible {
            optiDebugLog("[CircleRingController] 检测到屏幕配置变化，更新圆环位置")
            // 更新圆环位置以确保在屏幕边界内
            updateCircleRingPosition()
        }
    }
} 
