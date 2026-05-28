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
    @ObservedObject private var websiteManager = WebsiteManager.shared
    @State private var websiteSlots: [CircleRingWebsiteSlot] = []
    private var hoveredIndex: Int? { circleController.selectedAppIndex }
    @State var apps: [AppInfo] = []
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
    @State private var iconScales: [CGFloat] = []
    
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
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                // 创建一个完全透明的视图作为占位符
                Color.clear
                
                circleRingBackground
                .scaleEffect(settings.useCircleRingAnimation ? ringScale : 1)
                .opacity(settings.useCircleRingAnimation ? (showRingAnimation ? 1 : 0) : 1)
                
                // 当鼠标悬停时绘制扇区高亮
                if settings.useSectorHighlight, let hoveredIdx = hoveredIndex,
                   hoveredIdx < min(activeSectorCount, apps.count) {
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
                
            }
            .frame(width: settings.circleRingDiameter, height: settings.circleRingDiameter)
        }
        .frame(width: settings.circleRingDiameter, height: settings.circleRingDiameter)
        .padding(Self.outerPadding)
        .task(id: circleController.presentationID) {
            guard circleController.isVisible else { return }
            loadApps()
            await animateAppearance(presentationID: circleController.presentationID)
        }
        .onChange(of: activeContentMode) { _ in
            loadApps()
        }
        .onChange(of: hoveredIndex) { index in
            guard index != nil, circleController.isVisible else { return }
            if settings.useSectorHoverSound {
                soundPlayer.playRadarSound()
            }
            if settings.useSectorHoverHaptic {
                hapticFeedbackManager.playHapticFeedback()
            }
        }
        .onChange(of: settings.circleRingSectorCount) { _ in
            if activeContentMode == .apps {
                loadApps()
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
        .onChange(of: websiteManager.websites) { _ in
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
    
    // SwiftUI 管理任务生命周期；隐藏圆环时自动取消未完成的动画延时。
    @MainActor
    private func animateAppearance(presentationID: Int) async {
        let iconCount = min(activeSectorCount, apps.count)
        let animatesIcons = settings.iconAppearAnimationType != .none
        ringScale = settings.useCircleRingAnimation ? 0.5 : 1
        showRingAnimation = !settings.useCircleRingAnimation
        showIcons = Array(repeating: !animatesIcons || !settings.useCircleRingAnimation, count: iconCount)
        iconScales = Array(repeating: 0.5, count: iconCount)
        if settings.useCircleRingStartupSound {
            soundPlayer.playStartupSound()
        }
        guard settings.useCircleRingAnimation else { return }

        do {
            try await Task.sleep(nanoseconds: 50_000_000)
            guard circleController.isVisible, circleController.presentationID == presentationID else { return }
            withAnimation(.spring(response: settings.circleRingAnimationSpeed, dampingFraction: 0.7)) {
                showRingAnimation = true
                ringScale = 1
            }
            guard animatesIcons else { return }
            try await Task.sleep(nanoseconds: 150_000_000)
            let indices = settings.iconAppearAnimationType == .counterClockwise
                ? Array((0..<iconCount).reversed()) : Array(0..<iconCount)
            for (order, index) in indices.enumerated() {
                try Task.checkCancellation()
                guard circleController.isVisible, circleController.presentationID == presentationID else { return }
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0.2)) {
                    if index < showIcons.count && index < iconScales.count {
                        showIcons[index] = true
                        iconScales[index] = 1
                    }
                }
                if order < iconCount - 1 {
                    try await Task.sleep(nanoseconds: UInt64(max(0, settings.iconAppearSpeed) * 0.5 * 1_000_000_000))
                }
            }
        } catch is CancellationError {
            // 圆环已隐藏，丢弃本次展示的后续动画。
        } catch {
            optiDebugLog("[CircleRingView] 动画任务失败: \(error)")
        }
    }

    // 加载应用列表
    func loadApps() {
        defer {
            let count = min(activeSectorCount, apps.count)
            if showIcons.count != count {
                showIcons = Array(repeating: true, count: count)
                iconScales = Array(repeating: 1, count: count)
            }
        }
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
        let cache = ApplicationInfoCache.shared
        cache.retain(bundleIDs: configuredApps)
        var resolvedApps: [String: AppInfo] = [:]
        let slots = CircleRingAppSlot.resolve(
            configuredBundleIdentifiers: configuredApps,
            sectorCount: settings.circleRingSectorCount,
            applicationURL: { bundleId in
                let info = cache.info(for: bundleId)
                resolvedApps[bundleId] = info
                return info?.url
            }
        )

        apps = slots.map { slot in
            switch slot.state {
            case .available:
                return resolvedApps[slot.bundleId]!
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
        websiteSlots = CircleRingWebsiteSlot.resolve(
            configuredIDs: settings.circleRingWebsites,
            sectorCount: settings.circleRingWebsiteSectorCount,
            websites: websiteManager.websites
        )
        let fallbackIcon = NSImage(systemSymbolName: "globe", accessibilityDescription: "Website") ?? NSImage()
        apps = websiteSlots.map { slot in
            guard let website = slot.website else {
                return AppInfo(bundleId: "empty.website.\(slot.index)", name: "未配置", icon: fallbackIcon, url: nil)
            }
            return AppInfo(bundleId: "website.\(website.id.uuidString)", name: website.displayName,
                           icon: fallbackIcon, url: slot.url)
        }
        webIconManager.preloadIcons(for: websiteSlots.compactMap(\.website))
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
        let website = activeContentMode == .websites && index < websiteSlots.count ? websiteSlots[index].website : nil
        let icon = website.flatMap { webIconManager.icon(for: $0) } ?? app.icon
        
        return ZStack {
            // 应用图标
            Image(nsImage: icon)
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
        
        // 与 CircleRingSelection 保持一致：正上方为零，顺时针递增。
        
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
