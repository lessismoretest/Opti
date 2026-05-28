import Foundation
import SwiftUI
import AppKit
import Combine

// 鼠标使用屏幕坐标；从正上方开始，按顺时针顺序划分扇区。
struct CircleRingSelection {
    static func index(
        at location: CGPoint,
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        sectorCount: Int,
        isNearScreenEdge: Bool = false
    ) -> Int? {
        guard sectorCount > 0, outerRadius > 0 else { return nil }

        let dx = location.x - center.x
        let dy = center.y - location.y
        let distanceSquared = dx * dx + dy * dy
        let minimumRadius = isNearScreenEdge ? innerRadius * 0.9 : innerRadius
        let maximumRadius = isNearScreenEdge ? outerRadius * 1.1 : outerRadius
        guard distanceSquared >= minimumRadius * minimumRadius,
              distanceSquared <= maximumRadius * maximumRadius else {
            return nil
        }

        let angle = (atan2(dy, dx) + .pi / 2 + 2 * .pi)
            .truncatingRemainder(dividingBy: 2 * .pi)
        return min(sectorCount - 1, Int(angle / (2 * .pi / CGFloat(sectorCount))))
    }
}

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
    @Published private(set) var isVisible = false
    @Published private(set) var presentationID = 0
    
    // 监听Option键的本地监视器
    private var localEventMonitor: Any?
    
    // 监听Option键的全局监视器
    private var globalEventMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var settingsObserver: AnyCancellable?
    private var pendingSettingsUpdate: DispatchWorkItem?
    private var appliedLongPressThreshold: TimeInterval = 0
    private var appliedOptionKeyMode: OptionKeyActivationMode = .both
    private var displayedItemCount = 0
    
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
    @Published private(set) var selectedAppIndex: Int? = nil

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
        appliedLongPressThreshold = longPressThreshold
        appliedOptionKeyMode = settings.optionKeyActivationMode
        settingsObserver = settings.objectWillChange.sink { [weak self] _ in
            self?.scheduleSettingsUpdate()
        }
        
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
        pendingSettingsUpdate?.cancel()
        
        // 移除屏幕配置变化通知监听
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    // 本地和全局监听分别处理 Opti 内外的修饰键事件。
    private func setupEventMonitors() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    // 只在圆环显示时监听真实鼠标事件，不轮询、不生成模拟事件。
    private func startMouseMonitoring() {
        stopMouseMonitoring()
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]) { [weak self] event in
            self?.updateSelectionAtCurrentMousePosition()
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .leftMouseDown]) { [weak self] event in
            if event.type == .leftMouseDown {
                self?.hideCircleRing()
            } else {
                self?.updateSelectionAtCurrentMousePosition()
            }
        }
    }

    private func stopMouseMonitoring() {
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }

    private func refreshDisplayedItemCount() {
        displayedItemCount = activeSessionContentMode == .apps
            ? settings.circleRingSectorCount : settings.circleRingWebsiteSectorCount
    }

    private func updateSelectionAtCurrentMousePosition() {
        guard isVisible, let window else { return }
        let location = NSEvent.mouseLocation
        let outerRadius = settings.circleRingDiameter / 2
        let edgeThreshold = outerRadius * 0.3
        let screenFrame = NSScreen.screens.first(where: { NSPointInRect(location, $0.frame) })?.visibleFrame
        let isNearScreenEdge = screenFrame.map { frame in
            min(location.x - frame.minX, frame.maxX - location.x,
                location.y - frame.minY, frame.maxY - location.y) < edgeThreshold
        } ?? false
        let sectorCount = activeSessionContentMode == .apps
            ? settings.circleRingSectorCount : settings.circleRingWebsiteSectorCount
        let index = CircleRingSelection.index(
            at: location,
            center: CGPoint(x: window.frame.midX, y: window.frame.midY),
            innerRadius: settings.circleRingInnerDiameter / 2,
            outerRadius: outerRadius,
            sectorCount: min(sectorCount, displayedItemCount),
            isNearScreenEdge: isNearScreenEdge
        )
        if selectedAppIndex != index {
            selectedAppIndex = index
        }
    }

    // 移除事件监听器
    private func removeEventMonitors() {
        stopMouseMonitoring()
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
        guard settings.enableCircleRingMode else { return }
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
    
    // 松键时同步读取最终位置，选择不依赖绘制或动画完成。
    private func handleOptionKeyRelease() {
        cancelLongPressTimer()
        updateSelectionAtCurrentMousePosition()
        let selectedIndex = selectedAppIndex
        let sessionContentMode = activeSessionContentMode
        hideCircleRing()
        guard let selectedIndex, selectedIndex < displayedItemCount else { return }

        if sessionContentMode == .websites {
            let slots = CircleRingWebsiteSlot.resolve(
                configuredIDs: settings.circleRingWebsites,
                sectorCount: settings.circleRingWebsiteSectorCount,
                websites: WebsiteManager.shared.websites
            )
            guard selectedIndex < slots.count, let url = slots[selectedIndex].url else { return }
            NSWorkspace.shared.open(url)
            settings.incrementUsageCount(type: .circleRing)
            return
        }

        let bundleId = selectedIndex < settings.circleRingApps.count ? settings.circleRingApps[selectedIndex] : ""
        // 启动前只校验选中的应用，避免逐个解析整个圆环；不依赖显示缓存判断可用性。
        guard !bundleId.isEmpty, NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil else {
            DispatchQueue.main.async {
                self.showUnavailableApplicationAlert(bundleIdentifier: bundleId.isEmpty ? nil : bundleId)
            }
            return
        }

        if settings.clickCircleAppToToggle,
           let currentApp = NSWorkspace.shared.frontmostApplication,
           currentApp.bundleIdentifier == bundleId,
           let lastApp = HotKeyManager.shared.getLastActiveApp(),
           lastApp.bundleIdentifier != currentApp.bundleIdentifier,
           !lastApp.isTerminated {
            settings.incrementUsageCount(type: .circleRing)
            DispatchQueue.main.async {
                HotKeyManager.shared.switchToApp(bundleIdentifier: lastApp.bundleIdentifier ?? "")
            }
            return
        }

        HotKeyManager.shared.switchToApp(bundleIdentifier: bundleId)
        settings.incrementUsageCount(type: .circleRing)
    }

    func showUnavailableApplicationAlert(bundleIdentifier: String?) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.addButton(withTitle: "知道了")

        if let bundleIdentifier {
            alert.messageText = "应用已失效"
            alert.informativeText = "无法找到 \(bundleIdentifier)。这个应用可能已被移动或卸载；圆环中的位置和配置不会被自动更改。"
        } else {
            alert.messageText = "这个位置没有配置应用"
            alert.informativeText = "请在 Opti 设置的“应用圆环设置”中为这个位置选择应用。"
        }

        alert.runModal()
    }

    private func updateContentMode(_ newMode: ContentMode) {
        guard contentMode != newMode || (isVisible && activeSessionContentMode != newMode) else {
            return
        }

        contentMode = newMode

        if isVisible {
            activeSessionContentMode = newMode
            selectedAppIndex = nil
            refreshDisplayedItemCount()
            updateSelectionAtCurrentMousePosition()
        }
    }

    private func updateContentModeWhileOptionHeld(isCommandKeyDown: Bool) {
        // Option 控制圆环显示，Command 的当前状态决定应用或网站模式。
        updateContentMode(isCommandKeyDown ? .websites : .apps)
    }

    // 显示时复用已有窗口，并立即按当前鼠标位置计算选择。
    func showCircleRing() {
        guard settings.enableCircleRingMode, !isVisible else { return }
        let mouseLocation = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) ?? NSScreen.main
        let safeZoneMargin = settings.circleRingSafeZoneMargin
        if safeZoneMargin > 0, let frame = currentScreen?.frame {
            let distance = min(mouseLocation.x - frame.minX, frame.maxX - mouseLocation.x,
                               mouseLocation.y - frame.minY, frame.maxY - mouseLocation.y)
            guard distance >= safeZoneMargin else { return }
        }

        settings.incrementUsageCount(type: .optionLongPress)
        activeSessionContentMode = contentMode
        refreshDisplayedItemCount()
        if window == nil {
            createCircleRingWindow()
        }
        currentMouseLocation = mouseLocation
        updateCircleRingPosition()
        window?.orderFront(nil)
        isVisible = true
        presentationID += 1
        startMouseMonitoring()
        updateSelectionAtCurrentMousePosition()
    }

    // 隐藏圆环
    func hideCircleRing() {
        guard isVisible else { return }
        
        stopMouseMonitoring()
        selectedAppIndex = nil
        
        window?.orderOut(nil)
        isVisible = false
        presentationID += 1
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
        let size = settings.circleRingDiameter + 2 * CircleRingView.outerPadding
        
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
        window.acceptsMouseMovedEvents = true
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
        
        // 圆环视图自身定义形状；窗口保持透明，不裁掉玻璃外沿和动画。
        self.window = window
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
    
    // @Published 在赋值前通知；合并同一轮修改后读取最终配置。
    private func scheduleSettingsUpdate() {
        guard pendingSettingsUpdate == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingSettingsUpdate = nil
            self.applySettings()
        }
        pendingSettingsUpdate = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func applySettings() {
        if !settings.enableCircleRingMode {
            hideCircleRing()
            resetTransientState()
        }
        if appliedLongPressThreshold != longPressThreshold {
            cancelLongPressTimer()
            appliedLongPressThreshold = longPressThreshold
        }
        if appliedOptionKeyMode != settings.optionKeyActivationMode {
            hideCircleRing()
            resetTransientState()
            appliedOptionKeyMode = settings.optionKeyActivationMode
        }
        if let window {
            let size = settings.circleRingDiameter + 2 * CircleRingView.outerPadding
            if window.frame.size != NSSize(width: size, height: size) {
                window.setContentSize(NSSize(width: size, height: size))
                if isVisible {
                    updateCircleRingPosition()
                }
            }
            window.animationBehavior = settings.useCircleRingAnimation ? .none : .utilityWindow
        }
        refreshDisplayedItemCount()
        updateSelectionAtCurrentMousePosition()
    }

    // 调试入口也复用正常的显示和隐藏流程。
    func debugShowCircleRing() {
        hideCircleRing()
        showCircleRing()
    }

    // 处理屏幕配置变化
    @objc private func handleScreenConfigurationChange() {
        if isVisible {
            optiDebugLog("[CircleRingController] 检测到屏幕配置变化，更新圆环位置")
            // 更新圆环位置以确保在屏幕边界内
            updateCircleRingPosition()
            updateSelectionAtCurrentMousePosition()
        }
    }
} 
