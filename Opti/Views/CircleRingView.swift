import SwiftUI
import AppKit
import AVFoundation
import AudioToolbox
import IOKit
import IOKit.hid

// 添加震动反馈管理器
class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    // 节流控制
    private var lastFeedbackTime: TimeInterval = 0
    private let throttleInterval: TimeInterval = 0.15 // 150毫秒节流间隔
    
    // 检查设备是否支持Force Touch触控板
    var isHapticFeedbackSupported: Bool {
        // 在macOS中没有直接的API检查是否支持Force Touch
        // 我们可以尝试通过间接方式检测
        // 注意：这只是最佳猜测，不是100%准确
        if #available(macOS 10.11, *) {
            // 检查是否为笔记本电脑
            let isLaptop = self.checkIfLaptop()
            // 在10.15之后的Mac笔记本大多数支持Force Touch
            if #available(macOS 10.15, *), isLaptop {
                return true
            }
            
            // 尝试检查是否有触控板
            let matchingDict = IOServiceMatching("AppleMultitouchDevice")
            let iterator = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, UnsafeMutablePointer<io_iterator_t>.allocate(capacity: 1))
            if iterator != 0 {
                return true
            }
        }
        
        return false
    }
    
    // 检查当前设备是否为笔记本电脑
    private func checkIfLaptop() -> Bool {
        // 通过设备型号间接判断
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        if service != 0 {
            // 获取设备型号
            if let modelData = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0) {
                let modelName = (modelData.takeUnretainedValue() as? Data)?.withUnsafeBytes { bytes in
                    bytes.baseAddress.map { String(cString: $0.assumingMemoryBound(to: CChar.self)) }
                } ?? ""
                
                // 释放资源
                IOObjectRelease(service)
                
                // MacBook系列通常包含"Book"字符串
                return modelName.contains("Book")
            }
            IOObjectRelease(service)
        }
        return false
    }
    
    private init() {}
    
    // 播放震动反馈
    func playHapticFeedback(strength: HapticFeedbackStrength? = nil) {
        // 获取当前时间
        let currentTime = ProcessInfo.processInfo.systemUptime
        
        // 应用节流策略
        if currentTime - lastFeedbackTime < throttleInterval {
            return
        }
        
        // 更新上次反馈时间
        lastFeedbackTime = currentTime
        
        // 获取实际使用的强度
        let actualStrength = strength ?? AppSettings.shared.sectorHoverHapticStrength
        
        // 使用NSHapticFeedbackManager提供触觉反馈 (仅在支持Force Touch的设备上有效)
        let hapticFeedbackPerformer = NSHapticFeedbackManager.defaultPerformer
        
        // 根据用户选择的强度设置反馈类型
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch actualStrength {
        case .light:
            pattern = .alignment
        case .medium:
            pattern = .levelChange
        case .strong:
            pattern = .generic
        }
        
        // 执行触觉反馈
        hapticFeedbackPerformer.perform(pattern, performanceTime: .default)
        
        // 同时为不支持Force Touch的设备播放系统音效作为备选反馈
        var systemSoundID: SystemSoundID
        switch actualStrength {
        case .light:
            systemSoundID = 1104 // kSystemSoundID_Tink
        case .medium:
            systemSoundID = 1057 // kSystemSoundID_PopupClosed
        case .strong:
            systemSoundID = 1107 // kSystemSoundID_SonarSound
        }
        
        // 播放系统音效
        AudioServicesPlaySystemSound(systemSoundID)
    }
}

/**
 * 圆环视图
 * 显示圆环形式的应用快捷图标
 */
struct CircleRingView: View {
    // 为玻璃外沿、阴影和展开动画的回弹保留绘制空间。
    static let outerPadding: CGFloat = 32

    @StateObject private var settings = AppSettings.shared
    @StateObject private var circleController = CircleRingController.shared
    @ObservedObject private var webIconManager = WebIconManager.shared
    @State private var hoveredIndex: Int? = nil
    @State var apps: [AppInfo] = []
    @State var selectedIndex: Int? = nil
    @Environment(\.colorScheme) var systemColorScheme
    
    // 音效播放器
    private let soundPlayer = SoundPlayer.shared
    
    // 震动反馈管理器
    private let hapticFeedbackManager = HapticFeedbackManager.shared
    
    // 添加状态变量追踪动画
    @State private var showRingAnimation: Bool = false
    @State private var ringScale: CGFloat = 0.5
    
    // 添加图标显示动画状态
    @State private var showIcons: [Bool] = []
    @State private var iconAnimationCompleted: Bool = false
    @State private var iconScales: [CGFloat] = []
    
    // 鼠标移动节流控制
    @State private var lastProcessTime: TimeInterval = 0
    @State private var pendingMouseLocation: CGPoint? = nil
    @State private var baseThrottleInterval: TimeInterval = 0.012 // 基础节流间隔12ms
    @State private var lastSectorChange: TimeInterval = 0
    @State private var previousSectorIndex: Int? = nil
    
    // 是否开启调试模式
    private let isDebugging = false
    
    private var circleRadius: CGFloat {
        settings.circleRingDiameter / 2
    }
    
    // 根据设置获取当前应该使用的颜色方案
    private var effectiveColorScheme: ColorScheme {
        switch settings.circleRingTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return systemColorScheme
        }
    }
    
    private var glassTintColor: Color {
        effectiveColorScheme == .dark ? Color.black.opacity(0.15) : Color.white.opacity(0.15)
    }

    private var backgroundColor: Color {
        effectiveColorScheme == .dark ? Color.black.opacity(settings.circleRingOpacity) : Color.white.opacity(settings.circleRingOpacity)
    }
    
    // 获取悬停背景颜色
    private var hoverBackgroundColor: Color {
        effectiveColorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2)
    }
    
    // 获取扇区高亮颜色
    private var sectorHighlightColor: Color {
        // 如果用户选择了自定义颜色（非auto），直接使用该颜色
        if settings.sectorHighlightColor != .auto {
            return settings.sectorHighlightColor.color.opacity(settings.sectorHighlightOpacity)
        }
        
        // 否则根据当前主题自动选择颜色
        if effectiveColorScheme == .dark {
            return Color.white.opacity(settings.sectorHighlightOpacity)
        } else {
            return Color.black.opacity(settings.sectorHighlightOpacity)
        }
    }
    
    // 获取文本颜色
    private var textColor: Color {
        effectiveColorScheme == .dark ? Color.white : Color.black
    }
    
    // 获取文本背景颜色
    private var textBackgroundColor: Color {
        effectiveColorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.7)
    }
    
    // 记录当前鼠标在哪个扇区
    private var currentSectorIndex: Int = -1

    private var activeSectorCount: Int {
        activeContentMode == .websites
            ? settings.circleRingWebsiteSectorCount
            : settings.circleRingSectorCount
    }

    private var activeContentMode: CircleRingController.ContentMode {
        circleController.isVisible ? circleController.activeSessionContentMode : circleController.contentMode
    }
    
    // 计算智能节流间隔 - 根据圆环大小和扇区数量动态调整
    private var throttleInterval: TimeInterval {
        let baseFactor = min(1.0, Double(settings.circleRingDiameter) / 500.0) // 直径越小，节流越短
        let sectorFactor = min(1.0, Double(12) / Double(activeSectorCount)) // 扇区越多，节流越短
        
        // 计算最终节流间隔，范围在8-15ms之间
        return max(0.008, min(0.015, baseThrottleInterval * baseFactor * sectorFactor))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 创建一个完全透明的视图作为占位符
                Color.clear
                
                circleRingBackground
                .scaleEffect(settings.useCircleRingAnimation ? ringScale : 1)
                .opacity(settings.useCircleRingAnimation ? (showRingAnimation ? 1 : 0) : 1)
                
                // 当鼠标悬停时绘制扇区高亮
                if settings.useSectorHighlight, let hoveredIdx = hoveredIndex {
                    // 使用一个ZStack包裹以确保id正确应用于整个扇区
                    ZStack {
                        sectorHighlightShape(for: hoveredIdx)
                            .fill(sectorHighlightColor)
                    }
                    .animation(.easeInOut(duration: 0.2), value: hoveredIdx)
                    .transition(.opacity)
                    .id("sector-\(hoveredIdx)")  // 确保使用唯一id
                }
                
                // 显示自定义图片 - 应用圆环和网站圆环分别使用各自配置
                let showingWebsites = activeContentMode == .websites
                let activeShowCustomImage = showingWebsites
                    ? settings.showCustomImageInWebsiteCircle
                    : settings.showCustomImageInCircle
                let activeCustomImagePath = showingWebsites
                    ? settings.customWebsiteCircleImagePath
                    : settings.customCircleImagePath
                let activeCustomImageScale = showingWebsites
                    ? settings.customWebsiteCircleImageScale
                    : settings.customCircleImageScale
                let activeCustomImageOpacity = showingWebsites
                    ? settings.customWebsiteCircleImageOpacity
                    : settings.customCircleImageOpacity

                if activeShowCustomImage && !activeCustomImagePath.isEmpty {
                    CustomCircleImage(imagePath: activeCustomImagePath,
                                    diameter: settings.circleRingInnerDiameter,
                                    scale: activeCustomImageScale,
                                    opacity: activeCustomImageOpacity)
                        .id("\(showingWebsites ? "websites" : "apps")-\(activeCustomImagePath)")
                        .scaleEffect(settings.useCircleRingAnimation ? ringScale : 1)
                        .opacity(settings.useCircleRingAnimation ? (showRingAnimation ? 1 : 0) : 1)
                }
                
                // 应用图标
                ForEach(0..<min(activeSectorCount, apps.count), id: \.self) { index in
                    appIconView(for: index)
                        .zIndex(hoveredIndex == index ? 1 : 0)
                        .opacity(settings.useCircleRingAnimation ? 
                                (settings.iconAppearAnimationType != .none ? 
                                 (index < showIcons.count && showIcons[index] ? 1 : 0) : 
                                 (showRingAnimation ? 1 : 0)) : 
                                1)
                }
                
                // 圆环背景，用于捕获全局鼠标移动
                Circle()
                    .fill(Color.clear)
                    .frame(width: settings.circleRingDiameter, height: settings.circleRingDiameter)
                    .contentShape(Circle()) // 显式设置命中测试形状
                    .allowsHitTesting(true)
                    .onHover { isHovered in
                        optiDebugLog("[CircleRingView] 鼠标悬停状态: \(isHovered ? "进入" : "离开")")
                        
                        // 如果鼠标离开视图，清除悬停索引
                        if !isHovered {
                            clearCurrentSelection()
                        } else {
                            // 鼠标进入时，立即检测位置
                            DispatchQueue.main.async {
                                // 获取当前鼠标位置并处理
                                // 寻找圆环窗口 - 使用更可靠的窗口检测方法
                                var circleRingWindow: NSWindow?
                                
                                // 1. 先尝试找没有标题的窗口（圆环窗口通常没有标题）
                                for window in NSApp.windows where window.isVisible && window.title.isEmpty {
                                    // 检查窗口尺寸是否接近圆环尺寸，帮助识别圆环窗口
                                    if abs(window.frame.width - (settings.circleRingDiameter + 2 * Self.outerPadding)) < 10 {
                                        circleRingWindow = window
                                        optiDebugLog("[CircleRingView] 悬停检测找到圆环窗口：尺寸匹配")
                                        break
                                    }
                                }
                                
                                // 2. 如果没找到，查找层级为popUpMenu的窗口
                                if circleRingWindow == nil {
                                    for window in NSApp.windows where window.isVisible && window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
                                        circleRingWindow = window
                                        optiDebugLog("[CircleRingView] 悬停检测找到圆环窗口：层级匹配")
                                        break
                                    }
                                }
                                
                                if let window = circleRingWindow {
                                    let mouseLocation = NSEvent.mouseLocation
                                    let windowOrigin = window.frame.origin
                                    
                                    // 将全局鼠标位置转换为视图内位置
                                    let viewX = mouseLocation.x - windowOrigin.x - Self.outerPadding
                                    let viewY = mouseLocation.y - windowOrigin.y - Self.outerPadding
                                    handleMouseMoved(location: CGPoint(x: viewX, y: viewY))
                                } else {
                                    optiDebugLog("[CircleRingView] 悬停检测无法找到窗口")
                                }
                            }
                        }
                    }
                    .gesture( // 使用普通手势以确保最高优先级
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // 当拖动手势开始或改变时，处理鼠标移动
                                handleMouseMoved(location: value.location)
                            }
                    )
                    .onAppear {
                        // 窗口出现时自动检测当前鼠标位置
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            // 获取窗口中心点，用于计算相对位置
                            let center = CGPoint(x: circleRadius, y: circleRadius)
                            handleMouseMoved(location: center)
                            optiDebugLog("[CircleRingView] 初始检测鼠标位置: \(center)")
                        }
                        
                        // 添加通知监听来强制更新鼠标位置
                        NotificationCenter.default.addObserver(
                            forName: NSNotification.Name("ForceUpdateMousePosition"),
                            object: nil,
                            queue: .main) { _ in
                                
                                // 寻找圆环窗口 - 使用更可靠的窗口检测方法
                                var circleRingWindow: NSWindow?
                                
                                // 1. 先尝试找没有标题的窗口（圆环窗口通常没有标题）
                                for window in NSApp.windows where window.isVisible && window.title.isEmpty {
                                    // 检查窗口尺寸是否接近圆环尺寸，帮助识别圆环窗口
                                    if abs(window.frame.width - (settings.circleRingDiameter + 2 * Self.outerPadding)) < 10 {
                                        circleRingWindow = window
                                        optiDebugLog("[CircleRingView] 强制更新找到圆环窗口：尺寸匹配")
                                        break
                                    }
                                }
                                
                                // 2. 如果没找到，查找层级为popUpMenu的窗口
                                if circleRingWindow == nil {
                                    for window in NSApp.windows where window.isVisible && window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
                                        circleRingWindow = window
                                        optiDebugLog("[CircleRingView] 强制更新找到圆环窗口：层级匹配")
                                        break
                                    }
                                }
                                
                                // 获取最新的鼠标位置
                                if let window = circleRingWindow {
                                    let mouseLocation = NSEvent.mouseLocation
                                    let windowOrigin = window.frame.origin
                                    
                                    // 将全局鼠标位置转换为视图内位置
                                    let viewX = mouseLocation.x - windowOrigin.x - Self.outerPadding
                                    let viewY = mouseLocation.y - windowOrigin.y - Self.outerPadding
                                    
                                    // 处理鼠标移动
                                    self.handleMouseMoved(location: CGPoint(x: viewX, y: viewY))
                                } else {
                                    optiDebugLog("[CircleRingView] 强制更新无法找到圆环窗口")
                                }
                            }
                    }
                    .onDisappear {
                        // 移除通知监听
                        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ForceUpdateMousePosition"), object: nil)
                    }
            }
            .frame(width: settings.circleRingDiameter, height: settings.circleRingDiameter)
        }
        .frame(width: settings.circleRingDiameter, height: settings.circleRingDiameter)
        .padding(Self.outerPadding)
        .onAppear {
            loadApps()
            optiDebugLog("[CircleRingView] 视图已出现，加载了 \(apps.count) 个应用")
            
            // 播放启动音效
            if settings.useCircleRingStartupSound {
                soundPlayer.playStartupSound()
            }
            
            // 添加动画效果
            if settings.useCircleRingAnimation {
                // 确保每次视图出现时都重置动画状态
                ringScale = 0.5
                showRingAnimation = false
                iconAnimationCompleted = false
                
                // 重置图标显示状态
                if settings.iconAppearAnimationType != .none {
                    showIcons = Array(repeating: false, count: min(activeSectorCount, apps.count))
                    iconScales = Array(repeating: 0.5, count: min(activeSectorCount, apps.count))
                }
                
                // 延迟一点点再开始动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: settings.circleRingAnimationSpeed, dampingFraction: 0.7)) {
                        showRingAnimation = true
                        ringScale = 1.0
                    }
                    
                    // 如果启用了图标显示动画
                    if settings.iconAppearAnimationType != .none {
                        // 圆环展开后开始图标动画 - 减少延迟从0.3秒到0.15秒
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            let iconCount = min(activeSectorCount, apps.count)
                            
                            // 根据动效类型确定图标显示顺序
                            let indices: [Int]
                            switch settings.iconAppearAnimationType {
                            case .clockwise:
                                indices = Array(0..<iconCount) // 顺时针：0,1,2,3...
                            case .counterClockwise:
                                indices = Array((0..<iconCount).reversed()) // 逆时针：n,n-1,n-2...
                            default:
                                indices = Array(0..<iconCount)
                            }
                            
                            // 按确定的顺序显示图标 - 减少每个图标的显示间隔
                            for (displayOrder, i) in indices.enumerated() {
                                // 减少每个图标的显示延迟，使用图标显示速度的一半
                                let iconDelay = Double(displayOrder) * (Double(settings.iconAppearSpeed) * 0.5)
                                DispatchQueue.main.asyncAfter(deadline: .now() + iconDelay) {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0.2)) {
                                        if i < showIcons.count {
                                            showIcons[i] = true
                                            iconScales[i] = 1.2 // 先放大超过目标大小
                                        }
                                    }
                                    
                                    // 额外添加一个弹性回弹动画，延迟时间减少但保持比例
                                    DispatchQueue.main.asyncAfter(deadline: .now() + max(0.04, Double(settings.iconAppearSpeed))) {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                            if i < iconScales.count {
                                                iconScales[i] = 1.0 // 回弹到正常大小
                                            }
                                        }
                                    }
                                    
                                    // 最后一个图标显示完成后，标记动画完成 - 减少延迟但保留一定的完成等待时间
                                    if displayOrder == iconCount - 1 {
                                        let completionDelay = max(0.05, Double(settings.iconAppearSpeed) * 1.5)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay) {
                                            iconAnimationCompleted = true
                                            circleController.iconsAnimationCompleted = true
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // 如果未启用图标显示动画，直接标记为完成
                        iconAnimationCompleted = true
                        circleController.iconsAnimationCompleted = true
                    }
                }
            } else {
                // 如果不使用动画，确保直接显示
                showRingAnimation = true
                ringScale = 1.0
                iconAnimationCompleted = true
                circleController.iconsAnimationCompleted = true
            }
            
            // 添加通知观察者，用于响应圆环重新显示的通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CircleRingDidAppear"),
                object: nil,
                queue: .main) { [self] _ in
                    guard settings.useCircleRingAnimation else { return }
                    
                    // 重置动画状态
                    self.ringScale = 0.5
                    self.showRingAnimation = false
                    self.iconAnimationCompleted = false
                    
                    // 重置图标显示状态
                    if settings.iconAppearAnimationType != .none {
                        self.showIcons = Array(repeating: false, count: min(activeSectorCount, self.apps.count))
                        self.iconScales = Array(repeating: 0.5, count: min(activeSectorCount, self.apps.count))
                    }
                    
                    // 立即应用动画
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: settings.circleRingAnimationSpeed, dampingFraction: 0.7)) {
                            self.showRingAnimation = true
                            self.ringScale = 1.0
                        }
                        
                        // 如果启用了图标显示动画
                        if settings.iconAppearAnimationType != .none {
                            // 圆环展开后开始图标动画 - 减少延迟从0.3秒到0.15秒
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                let iconCount = min(activeSectorCount, self.apps.count)
                                
                                // 根据动效类型确定图标显示顺序
                                let indices: [Int]
                                switch settings.iconAppearAnimationType {
                                case .clockwise:
                                    indices = Array(0..<iconCount) // 顺时针：0,1,2,3...
                                case .counterClockwise:
                                    indices = Array((0..<iconCount).reversed()) // 逆时针：n,n-1,n-2...
                                default:
                                    indices = Array(0..<iconCount)
                                }
                                
                                // 按确定的顺序显示图标 - 减少每个图标的显示间隔
                                for (displayOrder, i) in indices.enumerated() {
                                    // 减少每个图标的显示延迟，使用图标显示速度的一半
                                    let iconDelay = Double(displayOrder) * (Double(settings.iconAppearSpeed) * 0.5)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + iconDelay) {
                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0.2)) {
                                            if i < self.showIcons.count {
                                                self.showIcons[i] = true
                                                self.iconScales[i] = 1.2 // 先放大超过目标大小
                                            }
                                        }
                                        
                                        // 额外添加一个弹性回弹动画，延迟时间减少但保持比例
                                        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.04, Double(settings.iconAppearSpeed))) {
                                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                                if i < self.iconScales.count {
                                                    self.iconScales[i] = 1.0 // 回弹到正常大小
                                                }
                                            }
                                        }
                                        
                                        // 最后一个图标显示完成后，标记动画完成 - 减少延迟但保留一定的完成等待时间
                                        if displayOrder == iconCount - 1 {
                                            let completionDelay = max(0.05, Double(settings.iconAppearSpeed) * 1.5)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay) {
                                                self.iconAnimationCompleted = true
                                                self.circleController.iconsAnimationCompleted = true
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // 如果未启用图标显示动画，直接标记为完成
                            self.iconAnimationCompleted = true
                            self.circleController.iconsAnimationCompleted = true
                        }
                    }
                    
                    optiDebugLog("[CircleRingView] 响应圆环显示通知，应用动画效果")
                }
        }
        .onDisappear {
            // 移除通知监听
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ForceUpdateMousePosition"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CircleRingDidAppear"), object: nil)
        }
        .onChange(of: circleController.contentMode) { _ in
            loadApps()
            DispatchQueue.main.async {
                refreshSelectionAtCurrentMousePosition()
            }
        }
        .onChange(of: circleController.activeSessionContentMode) { _ in
            loadApps()
            DispatchQueue.main.async {
                refreshSelectionAtCurrentMousePosition()
            }
        }
        .onChange(of: settings.circleRingApps) { _ in
            if activeContentMode == .apps {
                loadApps()
            }
        }
        .onChange(of: settings.circleRingWebsites) { _ in
            if activeContentMode == .websites {
                loadApps()
            }
        }
        .onChange(of: settings.circleRingWebsiteSectorCount) { _ in
            if activeContentMode == .websites {
                loadApps()
            }
        }
    }

    @ViewBuilder
    private var circleRingBackground: some View {
        let shape = RingShape(
            innerRadius: settings.circleRingInnerDiameter / 2,
            outerRadius: settings.circleRingDiameter / 2
        )

        switch settings.circleRingBackgroundEffect {
        case .liquidGlass:
            if #available(macOS 26.0, *) {
                shape
                    .fill(Color.clear)
                    .glassEffect(.regular.tint(glassTintColor).interactive(), in: shape)
            } else {
                legacyBlurBackground(shape: shape)
            }
        case .legacyBlur:
            legacyBlurBackground(shape: shape)
        case .solid:
            shape.fill(backgroundColor)
        }
    }

    private func legacyBlurBackground(shape: RingShape) -> some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.fill(backgroundColor.opacity(0.35)))
    }
    
    // 处理鼠标移动 - 入口函数
    private func handleMouseMoved(location: CGPoint) {
        // 记录当前鼠标位置以供节流间隔后处理
        pendingMouseLocation = location
        
        // 获取当前时间
        let currentTime = ProcessInfo.processInfo.systemUptime
        
        // 检查是否需要立即处理或应用节流
        let timeSinceLastProcess = currentTime - lastProcessTime
        
        // 应用节流策略：有三种情况会立即处理
        // 1. 超过节流间隔
        // 2. 第一次调用(lastProcessTime为0)
        // 3. 距离上次扇区变化后的首次移动(确保扇区变化得到及时响应)
        if timeSinceLastProcess >= throttleInterval || lastProcessTime == 0 || 
           (previousSectorIndex != nil && currentTime - lastSectorChange < 0.1) {
            processMouseMovement(location)
            lastProcessTime = currentTime
        } else {
            // 如果在节流期间，安排延迟处理
            DispatchQueue.main.asyncAfter(deadline: .now() + (throttleInterval - timeSinceLastProcess)) {
                // 仅当仍有待处理的位置且未被更新的处理取代时才执行
                if let pending = self.pendingMouseLocation {
                    self.processMouseMovement(pending)
                    self.pendingMouseLocation = nil
                    self.lastProcessTime = ProcessInfo.processInfo.systemUptime
                }
            }
        }
    }

    private func refreshSelectionAtCurrentMousePosition() {
        // 切换 app/website 模式后，立即按当前鼠标位置重算扇区，
        // 避免控制器已清空 selectedAppIndex 但视图尚未重新选中。
        var circleRingWindow: NSWindow?

        for window in NSApp.windows where window.isVisible && window.title.isEmpty {
            if abs(window.frame.width - (settings.circleRingDiameter + 2 * Self.outerPadding)) < 10 {
                circleRingWindow = window
                break
            }
        }

        if circleRingWindow == nil {
            for window in NSApp.windows where window.isVisible && window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
                circleRingWindow = window
                break
            }
        }

        guard let window = circleRingWindow else {
            optiDebugLog("[CircleRingView] 刷新选择时无法找到圆环窗口")
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let windowOrigin = window.frame.origin
        let viewX = mouseLocation.x - windowOrigin.x - Self.outerPadding
        let viewY = mouseLocation.y - windowOrigin.y - Self.outerPadding
        handleMouseMoved(location: CGPoint(x: viewX, y: viewY))
    }

    private func clearCurrentSelection() {
        withAnimation(.easeInOut(duration: 0.15)) {
            hoveredIndex = nil
        }
        selectedIndex = nil
        circleController.selectedAppIndex = nil
        previousSectorIndex = nil
    }
    
    // 实际处理鼠标移动的逻辑 - 从原有的handleMouseMoved拆分出来
    private func processMouseMovement(_ location: CGPoint) {
        // 计算鼠标相对于圆心的位置
        let relativeX = location.x - circleRadius
        let relativeY = circleRadius - location.y
        
        // 根据调试模式决定是否打印日志
        if isDebugging {
            optiDebugLog("[CircleRingView] 原始相对位置: (\(relativeX), \(relativeY))")
        }
        
        // 计算当前角度 - 使用标准数学坐标系中的atan2
        var angle = atan2(relativeY, relativeX)
        
        // 将角度规范化为 [0, 2π] 范围
        if angle < 0 {
            angle += 2 * .pi
        }
        
        // 计算距离圆心的距离
        let distance = sqrt(relativeX * relativeX + relativeY * relativeY)
        
        // 获取扇区总数
        let totalSectors = min(activeSectorCount, apps.count)
        if totalSectors == 0 {
            // 没有应用，不处理扇区
            return
        }
        
        // 检查位置是否在屏幕边缘
        // 如果在屏幕边缘，则放宽检测标准，以便于用户在屏幕边缘也能选择应用
        var isNearScreenEdge = false
        
        // 寻找圆环窗口 - 使用更可靠的窗口检测方法
        var circleRingWindow: NSWindow?
        
        // 1. 先尝试找没有标题的窗口（圆环窗口通常没有标题）
        for window in NSApp.windows where window.isVisible && window.title.isEmpty {
            // 检查窗口尺寸是否接近圆环尺寸，帮助识别圆环窗口
            if abs(window.frame.width - (settings.circleRingDiameter + 2 * Self.outerPadding)) < 10 {
                circleRingWindow = window
                break
            }
        }
        
        // 2. 如果没找到，查找层级为popUpMenu的窗口
        if circleRingWindow == nil {
            for window in NSApp.windows where window.isVisible && window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
                circleRingWindow = window
                break
            }
        }
        
        if let window = circleRingWindow {
            let mouseLocation = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) {
                let screenFrame = screen.visibleFrame
                
                // 计算鼠标距离屏幕边缘的距离
                let distanceToLeftEdge = mouseLocation.x - screenFrame.minX
                let distanceToRightEdge = screenFrame.maxX - mouseLocation.x
                let distanceToTopEdge = screenFrame.maxY - mouseLocation.y
                let distanceToBottomEdge = mouseLocation.y - screenFrame.minY
                
                // 确定边缘阈值 - 使用圆环半径的一小部分
                let edgeThreshold = circleRadius * 0.3
                
                // 判断是否靠近屏幕边缘
                isNearScreenEdge = distanceToLeftEdge < edgeThreshold ||
                                  distanceToRightEdge < edgeThreshold ||
                                  distanceToTopEdge < edgeThreshold ||
                                  distanceToBottomEdge < edgeThreshold
                
                if isNearScreenEdge && isDebugging {
                    optiDebugLog("[CircleRingView] 检测到鼠标靠近屏幕边缘，放宽扇区选择标准")
                }
            }
        } else {
            // 如果找不到窗口，保守地假设不在屏幕边缘
            isNearScreenEdge = false
            if isDebugging {
                optiDebugLog("[CircleRingView] 无法找到圆环窗口确定屏幕边缘")
            }
        }
        
        // 修改这里：使鼠标必须到达真正的圆环区域才识别扇区
        // 设置内外半径为实际的圆环边界
        let innerRadius = settings.circleRingInnerDiameter / 2
        let outerRadius = settings.circleRingDiameter / 2
        
        // 对于屏幕边缘的情况，可以适当放宽但不要太过宽松
        let actualInnerRadius = isNearScreenEdge ? innerRadius * 0.9 : innerRadius
        let actualOuterRadius = isNearScreenEdge ? outerRadius * 1.1 : outerRadius
        
        if isDebugging {
            optiDebugLog("[CircleRingView] 鼠标移动: 角度=\(angle * 180 / .pi)°, 距离=\(distance), 内径=\(actualInnerRadius), 外径=\(actualOuterRadius), 相对位置: (\(relativeX), \(relativeY)), 靠近屏幕边缘: \(isNearScreenEdge)")
        }
        
        // 扇区角度
        let angleSlice = 2 * .pi / CGFloat(totalSectors)
        
        // 计算扇区索引 - 第一个扇区从正上方开始，顺时针旋转
        var sectorIndex: Int
        
        // 将角度转换为以正上方为0度的坐标系
        let normalizedAngle = (angle + .pi / 2).truncatingRemainder(dividingBy: 2 * .pi)
        
        // 计算扇区索引
        sectorIndex = Int(floor(normalizedAngle / angleSlice))
        
        // 确保索引在有效范围内
        sectorIndex = sectorIndex % totalSectors
        
        // 优化悬停检测逻辑
        var validIndex: Int? = nil
        
        // 判断鼠标是否在实际的圆环区域内
        if distance < actualInnerRadius || distance > actualOuterRadius {
            // 鼠标不在圆环区域内，不选择任何扇区
            validIndex = nil
            // 确保清除选中状态
            selectedIndex = nil
            if isDebugging {
                optiDebugLog("[CircleRingView] 鼠标不在圆环区域内，清除选择")
            }
        } else {
            // 鼠标在圆环区域内
            validIndex = sectorIndex
            // 设置选中的索引
            selectedIndex = sectorIndex
        }
        
        // 如果扇区不同，更新悬停索引
        if validIndex != hoveredIndex {
            // 记录扇区变化时间，用于智能节流
            lastSectorChange = ProcessInfo.processInfo.systemUptime
            
            if isDebugging || previousSectorIndex != validIndex {
                optiDebugLog("[CircleRingView] 鼠标移动到扇区: \(String(describing: validIndex)), 角度: \(angle * 180 / .pi)°, 归一化角度: \(normalizedAngle * 180 / .pi)°, 扇区角度: \(angleSlice * 180 / .pi)°, 索引: \(sectorIndex)")
            }
            
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredIndex = validIndex
            }
            
            // 更新选中的应用索引
            selectedIndex = validIndex
            
            // 记录上一个扇区索引，用于检测变化
            previousSectorIndex = validIndex
            
            // 将当前选择的扇区索引同步到CircleRingController
            if let index = validIndex {
                circleController.selectedAppIndex = index
                if isDebugging {
                    optiDebugLog("[CircleRingView] 已更新CircleRingController的selectedAppIndex: \(index)")
                }
                
                // 如果启用了音效，播放雷达扫描音效
                // 注意：SoundPlayer内部已实现150毫秒的节流控制，防止频繁播放导致卡顿
                if settings.useSectorHoverSound {
                    soundPlayer.playRadarSound()
                }
                
                // 如果启用了震动，触发震动反馈
                if settings.useSectorHoverHaptic {
                    hapticFeedbackManager.playHapticFeedback()
                }
            } else {
                // 如果移出区域，也更新控制器的选中索引为nil
                circleController.selectedAppIndex = nil
                if isDebugging {
                    optiDebugLog("[CircleRingView] 清除CircleRingController的selectedAppIndex")
                }
            }
            
            // 如果图标变化了，则打印选择的应用信息
            if let idx = validIndex, idx < apps.count {
                optiDebugLog("[CircleRingView] 当前选中应用: \(apps[idx].name) (\(apps[idx].bundleId))")
            }
        }
    }
    
    // 加载应用列表
    func loadApps() {
        if activeContentMode == .websites {
            loadWebsites()
            optiDebugLog("[CircleRingView] 最终加载了 \(apps.count) 个网站")
            return
        }

        let configuredApps = settings.circleRingApps
        optiDebugLog("[CircleRingView] 开始加载用户配置的应用，共 \(configuredApps.count) 个")

        let unavailableIcon = NSImage(
            systemSymbolName: "exclamationmark.app.fill",
            accessibilityDescription: "应用已失效"
        ) ?? NSImage()
        let unconfiguredIcon = NSImage(
            systemSymbolName: "plus.app",
            accessibilityDescription: "未配置应用"
        ) ?? NSImage()
        let slots = CircleRingAppSlot.resolve(
            configuredBundleIdentifiers: configuredApps,
            sectorCount: settings.circleRingSectorCount,
            applicationURL: { bundleId in
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId)
            }
        )

        apps = slots.map { slot in
            switch slot.state {
            case .available(let url):
                let appName = url.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                optiDebugLog("[CircleRingView] 扇区 \(slot.index) 已加载应用: \(appName) (\(slot.bundleId))")
                return AppInfo(bundleId: slot.bundleId, name: appName, icon: icon, url: url)
            case .unavailable:
                optiDebugLog("[CircleRingView] ⚠️ 扇区 \(slot.index) 的应用已失效: \(slot.bundleId)")
                return AppInfo(
                    bundleId: slot.bundleId,
                    name: "应用已失效",
                    icon: unavailableIcon,
                    url: nil
                )
            case .unconfigured:
                optiDebugLog("[CircleRingView] 扇区 \(slot.index) 未配置应用")
                return AppInfo(
                    bundleId: "empty.\(slot.index)",
                    name: "未配置",
                    icon: unconfiguredIcon,
                    url: nil
                )
            }
        }
        
        optiDebugLog("[CircleRingView] 最终加载了 \(apps.count) 个应用")
    }

    private func loadWebsites() {
        let websiteManager = WebsiteManager.shared
        let websitesById = Dictionary(uniqueKeysWithValues: websiteManager.getWebsites().map { ($0.id, $0) })
        let configuredWebsiteIds = settings.circleRingWebsites.compactMap(UUID.init(uuidString:))

        guard !configuredWebsiteIds.isEmpty else {
            apps = []
            optiDebugLog("[CircleRingView] 用户未配置网站圆环")
            return
        }

        let fallbackIcon = NSImage(
            systemSymbolName: "globe",
            accessibilityDescription: "Website"
        ) ?? NSImage()

        apps = configuredWebsiteIds.compactMap { websiteId in
            guard let website = websitesById[websiteId],
                  let websiteURL = URL(string: website.url) else {
                optiDebugLog("[CircleRingView] ⚠️ 无法加载网站，ID: \(websiteId.uuidString)")
                return nil
            }

            let icon = webIconManager.icon(for: website) ?? fallbackIcon
            if webIconManager.icon(for: website) == nil {
                webIconManager.loadIcon(for: website) { _ in
                    self.loadApps()
                }
            }

            return AppInfo(
                bundleId: "website.\(website.id.uuidString)",
                name: website.displayName,
                icon: icon,
                url: websiteURL
            )
        }
    }
    
    // 计算每个应用图标的位置
    private func positionForIndex(_ index: Int, totalCount: Int) -> CGPoint {
        // 计算每个扇区的角度
        let angleSlice = 2 * CGFloat.pi / CGFloat(totalCount)
        let innerRadius = settings.circleRingInnerDiameter / 2
        let outerRadius = circleRadius
        
        // 计算图标应该放置的半径位置 - 内圈和外圈之间的中点
        let iconRadius = (innerRadius + outerRadius) / 2
        
        // 扇区中心角度 - 第一个扇区(index=0)从正上方开始，顺时针旋转
        let angle = (.pi / 2) - angleSlice * CGFloat(index) - (angleSlice / 2)
        
        // 计算位置 (注意SwiftUI中Y轴是向下为正，所以y坐标需要取反)
        let x = iconRadius * cos(angle)
        let y = -iconRadius * sin(angle)
        
        return CGPoint(x: x, y: y)
    }
    
    // 创建单个应用图标视图
    private func appIconView(for index: Int) -> some View {
        let totalCount = min(activeSectorCount, apps.count)
        let app = apps[index]
        let position = positionForIndex(index, totalCount: totalCount)
        let iconSize = settings.circleRingIconSize
        let displayIconSize = app.bundleId.hasPrefix("website.") ? iconSize * 0.86 : iconSize
        let isHovered = hoveredIndex == index
        
        return ZStack {
            // 应用图标
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: displayIconSize, height: displayIconSize)
                .cornerRadius(settings.circleRingIconCornerRadius)
                .shadow(color: .black.opacity(0.3), radius: isHovered ? 4 : 2, x: 0, y: 2)
                .scaleEffect(settings.useIconAppearAnimation && settings.useCircleRingAnimation ? 
                            (index < iconScales.count ? (showIcons[index] ? 1.0 : iconScales[index]) : 1.0) : 
                            (isHovered ? 1.1 : 1.0))
                .animation(.spring(response: 0.2), value: isHovered)
            
            // 显示应用名称
            if isHovered && settings.showAppNameInCircleRing {
                Text(app.name)
                    .font(.caption)
                    .foregroundColor(textColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(textBackgroundColor)
                    .cornerRadius(4)
                    .offset(y: iconSize / 2 + 16)
                    .transition(.opacity)
            }
        }
        .position(x: position.x + circleRadius, y: position.y + circleRadius)
    }
    
    // 计算扇区交互区域
    private func calculateSectorArea(for index: Int, totalCount: Int) -> some Shape {
        return sectorHighlightShape(for: index)
    }
    
    // 创建扇区高亮形状
    private func sectorHighlightShape(for index: Int) -> some Shape {
        let totalCount = min(activeSectorCount, apps.count)
        let angleSlice = 2 * .pi / CGFloat(totalCount)
        
        // 重要：使用与handleMouseMoved完全相同的角度计算逻辑
        // 注意 handleMouseMoved 中使用 normalizedAngle = (angle + .pi / 2).truncatingRemainder(dividingBy: 2 * .pi)
        // 计算扇区索引 sectorIndex = Int(floor(normalizedAngle / angleSlice))
        
        // 将扇区索引转换回角度范围
        // 计算扇区起始角度（扇区逆时针边缘）
        let sectorStartNormalizedAngle = angleSlice * CGFloat(index)
        // 计算扇区结束角度（扇区顺时针边缘）
        let sectorEndNormalizedAngle = angleSlice * CGFloat(index + 1)
        
        // 从规范化角度转换回原始atan2角度（减去π/2）
        let startAngle = sectorStartNormalizedAngle - (.pi / 2)
        let endAngle = sectorEndNormalizedAngle - (.pi / 2)
        
        optiDebugLog("[CircleRingView] 扇区高亮: 索引=\(index), 总数=\(totalCount), " +
              "扇区角度=\(angleSlice * 180 / .pi)°, " +
              "规范化起始角度=\(sectorStartNormalizedAngle * 180 / .pi)°, " +
              "规范化结束角度=\(sectorEndNormalizedAngle * 180 / .pi)°, " +
              "绘制起始角度=\(startAngle * 180 / .pi)°, " +
              "绘制结束角度=\(endAngle * 180 / .pi)°")
        
        return SectorShape(
            center: CGPoint(x: circleRadius, y: circleRadius),
            radius: circleRadius,
            innerRadius: settings.circleRingInnerDiameter / 2,  // 修改为与内圆完全相同的直径
            startAngle: startAngle,
            endAngle: endAngle,
            sectorIndex: index
        )
    }
    
    // 获取当前选中的应用信息
    func getSelectedApp() -> AppInfo? {
        guard let index = selectedIndex, index >= 0, index < apps.count else {
            optiDebugLog("[CircleRingView] getSelectedApp: 没有有效的选中索引, selectedIndex=\(String(describing: selectedIndex))")
            
            // 尝试使用悬停索引作为备用 - 但仅当悬停索引有效时
            if let hoverIndex = hoveredIndex, hoverIndex >= 0, hoverIndex < apps.count {
                optiDebugLog("[CircleRingView] getSelectedApp: 使用悬停索引作为备用, hoveredIndex=\(hoverIndex)")
                return apps[hoverIndex]
            }
            
            optiDebugLog("[CircleRingView] getSelectedApp: 没有选中任何扇区，返回nil")
            return nil
        }
        
        // 计算鼠标相对于圆心的位置，再次检查是否在有效范围内
        let mouseLocation = NSEvent.mouseLocation
        
        // 寻找圆环窗口 - 使用更可靠的窗口检测方法
        var circleRingWindow: NSWindow?
        
        // 1. 先尝试找没有标题的窗口（圆环窗口通常没有标题）
        for window in NSApp.windows where window.isVisible && window.title.isEmpty {
            // 检查窗口尺寸是否接近圆环尺寸，帮助识别圆环窗口
            if abs(window.frame.width - (settings.circleRingDiameter + 2 * Self.outerPadding)) < 10 {
                circleRingWindow = window
                optiDebugLog("[CircleRingView] 找到圆环窗口：尺寸匹配")
                break
            }
        }
        
        // 2. 如果没找到，查找层级为popUpMenu+2的窗口
        if circleRingWindow == nil {
            for window in NSApp.windows where window.isVisible && window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue {
                circleRingWindow = window
                optiDebugLog("[CircleRingView] 找到圆环窗口：层级匹配")
                break
            }
        }
        
        if let window = circleRingWindow {
            let windowOrigin = window.frame.origin
            let viewX = mouseLocation.x - windowOrigin.x - Self.outerPadding
            let viewY = mouseLocation.y - windowOrigin.y - Self.outerPadding
            
            // 计算相对于圆心的位置
            let relativeX = viewX - circleRadius
            let relativeY = circleRadius - viewY
            
            // 计算距离圆心的距离
            let distance = sqrt(relativeX * relativeX + relativeY * relativeY)
            
            // 修改这里：使用实际的圆环区域进行检查
            let innerRadius = settings.circleRingInnerDiameter / 2
            let outerRadius = settings.circleRingDiameter / 2
            
            if distance <= innerRadius || distance >= outerRadius {
                optiDebugLog("[CircleRingView] getSelectedApp: 鼠标不在有效区域内，距离=\(distance), 返回nil")
                return nil
            }
        } else {
            optiDebugLog("[CircleRingView] getSelectedApp: 无法找到圆环窗口，使用备用逻辑")
            // 如果找不到窗口，直接返回当前索引的应用
        }
        
        optiDebugLog("[CircleRingView] getSelectedApp: 返回选中的应用 #\(index) - \(apps[index].name)")
        return apps[index]
    }
    
    // 启动应用
    func launchApp(_ app: AppInfo) {
        // 隐藏圆环
        circleController.hideCircleRing()
        
        // 网站模式直接打开 URL
        if app.bundleId.hasPrefix("website."), let url = app.url {
            NSWorkspace.shared.open(url)
            settings.incrementUsageCount(type: .circleRing)
            optiDebugLog("[CircleRingView] 打开网站: \(app.name) -> \(url.absoluteString)")
            return
        }

        // 打开应用
        if let url = app.url {
            optiDebugLog("[CircleRingView] 正在尝试打开应用: \(app.name) (\(app.bundleId)), 路径: \(url.path)")
            
            HotKeyManager.shared.switchToApp(bundleIdentifier: app.bundleId)
            
            optiDebugLog("CircleRingView 启动应用: \(app.name)")
            
            // 增加使用计数
            settings.incrementUsageCount(type: .circleRing)
        } else {
            optiDebugLog("[CircleRingView] 无法启动应用，URL为nil: \(app.name) (\(app.bundleId))")
            circleController.showUnavailableApplicationAlert(
                bundleIdentifier: app.bundleId.hasPrefix("empty.") ? nil : app.bundleId
            )
        }
    }
}

// 扇区高亮形状，与鼠标检测完全匹配
struct SectorShape: Shape {
    let center: CGPoint
    let radius: CGFloat
    let innerRadius: CGFloat
    let startAngle: CGFloat  // 原始角度（atan2计算得到的角度）
    let endAngle: CGFloat    // 原始角度（atan2计算得到的角度）
    let sectorIndex: Int
    let cornerRadius: CGFloat = 3
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 为圆角稍微调整角度
        let cornerAdjustment = cornerRadius / (radius * 1.5)
        
        // 直接用于SwiftUI的角度，SwiftUI中0度在右侧，顺时针为正
        let swiftUIStartAngle = startAngle + cornerAdjustment
        let swiftUIEndAngle = endAngle - cornerAdjustment
        
        // 外弧起点
        let startPointOuter = CGPoint(
            x: center.x + radius * cos(swiftUIStartAngle),
            y: center.y + radius * sin(swiftUIStartAngle)
        )
        
        // 内弧起点
        let startPointInner = CGPoint(
            x: center.x + innerRadius * cos(swiftUIStartAngle),
            y: center.y + innerRadius * sin(swiftUIStartAngle)
        )
        
        // 外弧终点
        let endPointOuter = CGPoint(
            x: center.x + radius * cos(swiftUIEndAngle),
            y: center.y + radius * sin(swiftUIEndAngle)
        )
        
        // 内弧终点
        let endPointInner = CGPoint(
            x: center.x + innerRadius * cos(swiftUIEndAngle),
            y: center.y + innerRadius * sin(swiftUIEndAngle)
        )
        
        // 绘制路径
        path.move(to: startPointOuter)
        
        // 外弧 - SwiftUI中clockwise参数为false表示顺时针，因为SwiftUI的坐标系中Y轴向下
        path.addArc(
            center: center,
            radius: radius,
            startAngle: Angle(radians: Double(swiftUIStartAngle)),
            endAngle: Angle(radians: Double(swiftUIEndAngle)),
            clockwise: false // 顺时针
        )
        
        // 外弧终点到内弧终点的圆角过渡
        path.addQuadCurve(
            to: endPointInner,
            control: CGPoint(
                x: endPointOuter.x + cornerRadius * cos(swiftUIEndAngle + .pi/2),
                y: endPointOuter.y + cornerRadius * sin(swiftUIEndAngle + .pi/2)
            )
        )
        
        // 内弧 - 逆时针绘制
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: Angle(radians: Double(swiftUIEndAngle)),
            endAngle: Angle(radians: Double(swiftUIStartAngle)),
            clockwise: true // 逆时针
        )
        
        // 内弧起点到外弧起点的圆角过渡
        path.addQuadCurve(
            to: startPointOuter,
            control: CGPoint(
                x: startPointInner.x + cornerRadius * cos(swiftUIStartAngle - .pi/2),
                y: startPointInner.y + cornerRadius * sin(swiftUIStartAngle - .pi/2)
            )
        )
        
        return path
    }
}

// 音效播放器单例
class SoundPlayer {
    static let shared = SoundPlayer()
    
    // 音效播放器 - 分别为扇区悬停音效和启动音效创建缓存
    private var hoverSounds: [SectorHoverSoundType: NSSound] = [:]
    private var startupSounds: [CircleRingStartupSoundType: NSSound] = [:]
    
    // 节流控制
    private var lastPlayTime: TimeInterval = 0
    private let throttleInterval: TimeInterval = 0.15 // 150毫秒的节流间隔
    
    private init() {
        // 初始化所有音效
        prepareAllSounds()
    }
    
    private func prepareAllSounds() {
        // 预加载扇区悬停音效
        let hoverSoundTypes: [SectorHoverSoundType] = [
            .ping, .tink, .submarine, .bottle, .frog, .pop,
            .basso, .funk, .glass, .morse, .purr, .sosumi,
            .click
        ]
        
        for soundType in hoverSoundTypes {
            // 尝试使用NSSound
            if let sound = NSSound(named: getSystemSoundName(for: soundType)) {
                sound.volume = 0.7
                // 预加载并停止音效，减少首次播放延迟
                sound.play()
                sound.pause()
                
                hoverSounds[soundType] = sound
                optiDebugLog("[SoundPlayer] 成功加载扇区悬停音效 \(soundType.rawValue)")
            } else {
                // 无法加载指定音效时，尝试使用Tink作为备用
                if let tinkSound = NSSound(named: "Tink") {
                    hoverSounds[soundType] = tinkSound
                    optiDebugLog("[SoundPlayer] 无法加载扇区悬停音效 \(soundType.rawValue)，使用Tink替代")
                }
            }
        }
        
        // 预加载启动音效
        let startupSoundTypes: [CircleRingStartupSoundType] = [
            .hero, .magic, .sparkle, .chime, .bell,
            .crystal, .cosmic, .fairy, .mystic
        ]
        
        for soundType in startupSoundTypes {
            // 尝试使用NSSound
            if let sound = NSSound(named: getStartupSoundName(for: soundType)) {
                sound.volume = 0.7
                // 预加载并停止音效，减少首次播放延迟
                sound.play()
                sound.pause()
                
                startupSounds[soundType] = sound
                optiDebugLog("[SoundPlayer] 成功加载启动音效 \(soundType.rawValue)")
            } else {
                // 无法加载指定音效时，尝试使用Hero作为备用
                if let heroSound = NSSound(named: "Hero") {
                    startupSounds[soundType] = heroSound
                    optiDebugLog("[SoundPlayer] 无法加载启动音效 \(soundType.rawValue)，使用Hero替代")
                }
            }
        }
        
        // 测试所有声音是否已加载
        optiDebugLog("[SoundPlayer] 已加载 \(hoverSounds.count) 个扇区悬停音效和 \(startupSounds.count) 个启动音效")
    }
    
    // 将音效类型转换为系统声音文件名
    private func getSystemSoundName(for soundType: SectorHoverSoundType) -> String {
        switch soundType {
        case .ping: return "Ping"
        case .tink: return "Tink"
        case .submarine: return "Submarine"
        case .bottle: return "Bottle"
        case .frog: return "Frog"
        case .pop: return "Pop"
        case .basso: return "Basso"
        case .funk: return "Funk"
        case .glass: return "Glass"
        case .morse: return "Morse"
        case .purr: return "Purr"
        case .sosumi: return "Sosumi"
        case .click: return "Tink" // 使用Tink作为替代
        }
    }
    
    // 获取启动音效的系统声音名称
    private func getStartupSoundName(for soundType: CircleRingStartupSoundType) -> String {
        switch soundType {
        case .none: return ""
        case .hero: return "Hero"
        case .magic: return "Glass"  // 使用玻璃音效模拟魔法声音
        case .sparkle: return "Pop"  // 使用流行音效模拟闪耀声音
        case .chime: return "Tink"   // 使用Tink音效模拟风铃声
        case .bell: return "Bottle"  // 使用瓶子音效模拟钟声
        case .crystal: return "Ping"  // 使用Ping音效模拟水晶声音
        case .cosmic: return "Submarine"  // 使用潜水艇音效模拟宇宙声音
        case .fairy: return "Purr"   // 使用猫咪音效模拟精灵声音
        case .mystic: return "Morse"  // 使用摩尔斯音效模拟神秘声音
        }
    }
    
    func playStartupSound() {
        // 获取当前设置的启动音效类型
        let soundType = AppSettings.shared.circleRingStartupSoundType
        
        // 如果设置为无音效，直接返回
        if soundType == .none {
            return
        }
        
        // 从缓存中获取音效
        if let sound = startupSounds[soundType] {
            // 确保不重复播放，先停止当前播放
            if sound.isPlaying {
                sound.stop()
            }
            sound.currentTime = 0
            sound.play()
        } else {
            // 如果找不到当前类型的音效，使用默认音效
            if let defaultSound = startupSounds[.hero] {
                defaultSound.stop()
                defaultSound.currentTime = 0
                defaultSound.play()
            }
        }
    }
    
    func playRadarSound() {
        // 应用节流机制：检查是否已经超过了节流间隔
        let currentTime = ProcessInfo.processInfo.systemUptime
        if currentTime - lastPlayTime < throttleInterval {
            // 如果间隔太短，忽略此次播放请求
            return
        }
        
        // 更新上次播放时间
        lastPlayTime = currentTime
        
        // 获取当前设置的音效类型
        let soundType = AppSettings.shared.sectorHoverSoundType
        
        // 从缓存中获取音效
        if let sound = hoverSounds[soundType] {
            // 确保不重复播放，先停止当前播放
            if sound.isPlaying {
                sound.stop()
            }
            sound.currentTime = 0
            sound.play()
        } else {
            // 如果找不到当前类型的音效，使用默认音效
            if let defaultSound = hoverSounds[.tink] {
                defaultSound.stop()
                defaultSound.currentTime = 0
                defaultSound.play()
            }
        }
    }
    
    deinit {
        // 停止并释放所有NSSound
        for (_, sound) in hoverSounds {
            sound.stop()
        }
        hoverSounds.removeAll()
        
        for (_, sound) in startupSounds {
            sound.stop()
        }
        startupSounds.removeAll()
    }
}

// 添加一个环形Shape，用于只绘制圆环部分
struct RingShape: Shape {
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 计算圆心
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // 创建外圆路径
        path.addArc(center: center, 
                   radius: outerRadius, 
                   startAngle: Angle(degrees: 0), 
                   endAngle: Angle(degrees: 360), 
                   clockwise: false)
        
        // 创建内圆路径(逆时针方向，这样可以挖空内部)
        path.addArc(center: center, 
                   radius: innerRadius, 
                   startAngle: Angle(degrees: 360), 
                   endAngle: Angle(degrees: 0), 
                   clockwise: true)
        
        // 闭合路径
        path.closeSubpath()
        
        return path
    }
}

// 添加自定义图片视图组件
struct CustomCircleImage: View {
    let imagePath: String
    let diameter: CGFloat
    let scale: CGFloat
    let opacity: CGFloat
    
    @State private var image: NSImage?
    @State private var isGif: Bool = false
    
    var body: some View {
        Group {
            if let nsImage = image {
                if isGif {
                    // 使用动态GIF组件
                    AnimatedGIFView(image: nsImage)
                        .frame(width: diameter * scale, height: diameter * scale)
                        .clipShape(Circle())
                        .opacity(opacity)
                } else {
                    // 普通图片
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: diameter * scale, height: diameter * scale)
                        .clipShape(Circle()) // 添加圆形遮罩确保图片不超出内圆
                        .opacity(opacity)
                }
            } else {
                // 图片加载失败时的占位内容
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: diameter * scale, height: diameter * scale)
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: imagePath) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        // 重置图片状态
        image = nil
        isGif = false
        
        // 从路径加载图片
        if let url = URL(string: imagePath) {
            if url.scheme == "file" || url.scheme == nil {
                // 从本地文件加载
                let localPath = url.scheme == nil ? imagePath : url.path
                if let loadedImage = NSImage(contentsOfFile: localPath) {
                    image = loadedImage
                    // 检查是否是GIF
                    isGif = localPath.lowercased().hasSuffix(".gif")
                    optiDebugLog("[CustomCircleImage] 成功从本地文件加载图片: \(localPath), 是GIF: \(isGif)")
                } else {
                    optiDebugLog("[CustomCircleImage] 无法从本地文件加载图片: \(localPath)")
                }
            } else {
                // 从网络URL加载
                DispatchQueue.global().async {
                    if let imageData = try? Data(contentsOf: url),
                       let loadedImage = NSImage(data: imageData) {
                        DispatchQueue.main.async {
                            self.image = loadedImage
                            // 检查是否是GIF
                            self.isGif = url.absoluteString.lowercased().hasSuffix(".gif")
                            optiDebugLog("[CustomCircleImage] 成功从URL加载图片: \(url), 是GIF: \(self.isGif)")
                        }
                    } else {
                        optiDebugLog("[CustomCircleImage] 无法从URL加载图片: \(url)")
                    }
                }
            }
        } else {
            optiDebugLog("[CustomCircleImage] 无效的图片路径: \(imagePath)")
        }
    }
}

// 添加专门的动态GIF显示组件
struct AnimatedGIFView: NSViewRepresentable {
    let image: NSImage
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true // 关键设置：启用动画
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = image
    }
} 
