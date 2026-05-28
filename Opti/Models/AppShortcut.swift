import Foundation
import ServiceManagement
import SwiftUI

struct AppShortcut: Identifiable, Codable, Equatable, Hashable {
    let id = UUID()
    var key: String
    var bundleIdentifier: String
    var appName: String
    
    var displayKey: String {
        key
    }
    
    static func == (lhs: AppShortcut, rhs: AppShortcut) -> Bool {
        lhs.id == rhs.id &&
        lhs.key == rhs.key &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.appName == rhs.appName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(key)
        hasher.combine(bundleIdentifier)
        hasher.combine(appName)
    }
}

enum Theme: String, Codable {
    case light
    case dark
    case system
}

enum UsageType: String, Codable {
    case unknown
    case shortcut
    case optionClick
    case optionLongPress
    case circleRing
}

enum LastAppSwitchTrigger: String, Codable, CaseIterable {
    case disabled
    case option
    case rightCommand
    
    var description: String {
        switch self {
        case .disabled: return "不启用"
        case .option: return "Option 键"
        case .rightCommand: return "右侧 Command 键（默认）"
        }
    }
}

enum OptionKeyActivationMode: String, Codable, CaseIterable {
    case leftOnly
    case rightOnly
    case both

    var description: String {
        switch self {
        case .leftOnly: return "只启用左侧 Option"
        case .rightOnly: return "只启用右侧 Option"
        case .both: return "两侧都启用"
        }
    }
}

enum WindowPosition: String, Codable {
    case topLeft = "topLeft"
    case topCenter = "topCenter"
    case topRight = "topRight"
    case centerLeft = "centerLeft"
    case center = "center"
    case centerRight = "centerRight"
    case bottomLeft = "bottomLeft"
    case bottomCenter = "bottomCenter"
    case bottomRight = "bottomRight"
    case custom = "custom"
    
    var description: String {
        switch self {
        case .topLeft: return "左上角"
        case .topCenter: return "顶部居中"
        case .topRight: return "右上角"
        case .centerLeft: return "左侧居中"
        case .center: return "屏幕居中"
        case .centerRight: return "右侧居中"
        case .bottomLeft: return "左下角"
        case .bottomCenter: return "底部居中"
        case .bottomRight: return "右下角"
        case .custom: return "自定义位置"
        }
    }
}

// 快捷键标签位置枚举
enum ShortcutLabelPosition: String, Codable {
    case top = "top"
    case bottom = "bottom"
    case left = "left"
    case right = "right"
    
    var description: String {
        switch self {
        case .top: return "顶部"
        case .bottom: return "底部"
        case .left: return "左侧"
        case .right: return "右侧"
        }
    }
}


// 添加圆环主题枚举
enum CircleRingTheme: String, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var description: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }
}

enum CircleRingBackgroundEffect: String, Codable {
    case legacyBlur = "legacyBlur"
    case liquidGlass = "liquidGlass"
    case solid = "solid"
    
    var description: String {
        switch self {
        case .legacyBlur: return "传统毛玻璃"
        case .liquidGlass: return "官方 Liquid Glass"
        case .solid: return "纯色背景"
        }
    }
}

enum SectorHoverSoundType: String, Codable {
    case ping = "ping"
    case tink = "tink"
    case submarine = "submarine"
    case bottle = "bottle"
    case frog = "frog"
    case pop = "pop"
    case basso = "basso"
    case funk = "funk"
    case glass = "glass"
    case morse = "morse"
    case purr = "purr"
    case sosumi = "sosumi"
    // 轻快类音效
    case click = "click"
    
    var description: String {
        switch self {
        case .ping: return "Ping"
        case .tink: return "Tink"
        case .submarine: return "潜水艇"
        case .bottle: return "瓶子"
        case .frog: return "青蛙"
        case .pop: return "流行"
        case .basso: return "低音"
        case .funk: return "放克"
        case .glass: return "玻璃"
        case .morse: return "摩尔斯"
        case .purr: return "猫咪"
        case .sosumi: return "Sosumi"
        case .click: return "点击"
        }
    }
}

// 添加图标显示动效类型枚举
enum IconAppearAnimationType: String, Codable {
    case none = "none"
    case clockwise = "clockwise"
    case counterClockwise = "counterClockwise"
    
    var description: String {
        switch self {
        case .none: return "无动效"
        case .clockwise: return "顺时针"
        case .counterClockwise: return "逆时针"
        }
    }
}

// 添加扇区高亮颜色枚举
enum SectorHighlightColorType: String, Codable {
    case auto = "auto"
    case white = "white"
    case black = "black"
    case red = "red"
    case blue = "blue"
    case green = "green"
    case yellow = "yellow"
    case purple = "purple"
    case orange = "orange"
    
    var description: String {
        switch self {
        case .auto: return "自动(跟随主题)"
        case .white: return "白色"
        case .black: return "黑色"
        case .red: return "红色"
        case .blue: return "蓝色"
        case .green: return "绿色"
        case .yellow: return "黄色"
        case .purple: return "紫色"
        case .orange: return "橙色"
        }
    }
    
    var color: Color {
        switch self {
        case .auto: return Color.clear // 特殊标记，表示自动
        case .white: return Color.white
        case .black: return Color.black
        case .red: return Color.red
        case .blue: return Color.blue
        case .green: return Color.green
        case .yellow: return Color.yellow
        case .purple: return Color.purple
        case .orange: return Color.orange
        }
    }
}

// 添加震动强度枚举
enum HapticFeedbackStrength: String, Codable {
    case light = "light"
    case medium = "medium"
    case strong = "strong"
    
    var description: String {
        switch self {
        case .light: return "轻微"
        case .medium: return "中等"
        case .strong: return "强烈"
        }
    }
}

// 添加圆环启动音效类型枚举
enum CircleRingStartupSoundType: String, Codable {
    case none = "none"
    case hero = "hero"
    case magic = "magic"
    case sparkle = "sparkle"
    case chime = "chime"
    case bell = "bell"
    case crystal = "crystal"
    case cosmic = "cosmic"
    case fairy = "fairy"
    case mystic = "mystic"
    
    var description: String {
        switch self {
        case .none: return "无音效"
        case .hero: return "英雄登场"
        case .magic: return "魔法闪现"
        case .sparkle: return "星光闪耀"
        case .chime: return "风铃轻响"
        case .bell: return "钟声回荡"
        case .crystal: return "水晶共鸣"
        case .cosmic: return "宇宙之音"
        case .fairy: return "精灵低语"
        case .mystic: return "神秘召唤"
        }
    }
}


class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private var pendingSaveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.25
    
    // 圆环展开动效设置
    @Published var useCircleRingAnimation: Bool = true {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    // 圆环长按触发时间
    @Published var circleRingLongPressThreshold: CGFloat = 0 {
        didSet {
            scheduleSaveSettings()
        }
    }

    // 屏幕边缘安全区域距离（像素），在此范围内不触发圆环
    @Published var circleRingSafeZoneMargin: CGFloat = 150 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    
    // 圆环展开动效速度
    @Published var circleRingAnimationSpeed: CGFloat = 0.2 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    private var isInitializing = true
    @Published var windowPosition: WindowPosition = .center {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var iconSize: Double = 48 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var appIconSize: Double = 48 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var webIconSize: Double = 48 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var appIconsPerRow: Double = 5 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var webIconsPerRow: Double = 8 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var shortcuts: [AppShortcut] = [] {
        didSet {
            guard !isInitializing else { return }
            scheduleSaveSettings()
        }
    }
    @Published var theme: Theme = .system
    @Published var launchAtLogin: Bool = false
    @Published var totalUsageCount: Int = 0
    
    // 图标样式设置
    @Published var iconCornerRadius: Double = 8 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var iconBorderWidth: Double = 2 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var iconBorderColor: Color = .white {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var iconSpacing: Double = 4 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var iconGridSpacing: Double = 16 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var iconShadowRadius: Double = 2 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var useIconShadow: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var useHoverBackground: Bool = false {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var iconHoverBackgroundColor: Color = Color.blue.opacity(0.2) {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var iconHoverBackgroundPadding: Double = 4 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var iconHoverBackgroundCornerRadius: Double = 8 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    // 图标悬停动画设置
    @Published var useHoverAnimation: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var hoverScale: Double = 1.1 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var hoverAnimationDuration: Double = 0.2 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    // 图标标签设置
    @Published var showAppName: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var showWebsiteName: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var appNameFontSize: Double = 10 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var websiteNameFontSize: Double = 10 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    // 应用快捷键标签设置
    @Published var showAppShortcutLabel: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var appShortcutLabelPosition: ShortcutLabelPosition = .bottom {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var appShortcutLabelBackgroundColor: Color = .black.opacity(0.6) {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var appShortcutLabelTextColor: Color = .white {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var appShortcutLabelOffsetX: Double = 0 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var appShortcutLabelOffsetY: Double = 0 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var appShortcutLabelFontSize: Double = 10 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    // 网站快捷键标签设置
    @Published var showWebShortcutLabel: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var webShortcutLabelPosition: ShortcutLabelPosition = .bottom {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var webShortcutLabelBackgroundColor: Color = .black.opacity(0.6) {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var webShortcutLabelTextColor: Color = .white {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var webShortcutLabelOffsetX: Double = 0 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var webShortcutLabelOffsetY: Double = 0 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var webShortcutLabelFontSize: Double = 10 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    
    @Published var lastAppSwitchTrigger: LastAppSwitchTrigger = .rightCommand {
        didSet {
            scheduleSaveSettings()
        }
    }

    @Published var optionKeyActivationMode: OptionKeyActivationMode = .both {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    
    // ==== 圆环模式设置 ====
    @Published var enableCircleRingMode: Bool = false {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var showAppNameInCircleRing: Bool = true {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    @Published var circleRingDiameter: CGFloat = 280 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    @Published var circleRingIconSize: CGFloat = 40 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var circleRingIconCornerRadius: CGFloat = 8 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var circleRingSectorCount: Int = 6 {
        didSet {
            scheduleSaveSettings()
        }
    }

    @Published var circleRingWebsiteSectorCount: Int = 6 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var circleRingApps: [String] = [] {
        didSet {
            optiDebugLog("[AppSettings] 圆环应用更新: \(oldValue.count) -> \(circleRingApps.count)")
            scheduleSaveSettings()
        }
    }

    @Published var circleRingWebsites: [String] = [] {
        didSet {
            optiDebugLog("[AppSettings] 圆环网站更新: \(oldValue.count) -> \(circleRingWebsites.count)")
            scheduleSaveSettings()
        }
    }
    
    @Published var circleRingTheme: CircleRingTheme = .system {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }

    @Published var circleRingBackgroundEffect: CircleRingBackgroundEffect = .legacyBlur {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }

    @Published var circleRingOpacity: CGFloat = 0.8 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    @Published var circleRingInnerDiameter: CGFloat = 60 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    @Published var useSectorHighlight: Bool = true {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    @Published var sectorHighlightOpacity: CGFloat = 1.0 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    @Published var sectorHighlightColor: SectorHighlightColorType = .blue {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    @Published var useSectorHoverSound: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var useCircleRingStartupSound: Bool = false {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var circleRingStartupSoundType: CircleRingStartupSoundType = .none {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var sectorHoverSoundType: SectorHoverSoundType = .frog {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var useIconAppearAnimation: Bool = false {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    @Published var iconAppearAnimationType: IconAppearAnimationType = .none {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    @Published var iconAppearSpeed: CGFloat = 0.04 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    
    // 新增内圆自定义图片设置
    @Published var showCustomImageInCircle: Bool = false {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    // 存储自定义图片路径
    @Published var customCircleImagePath: String = "" {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    // 自定义图片大小比例(占内圆的百分比)
    @Published var customCircleImageScale: CGFloat = 0.7 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }
    
    // 自定义图片透明度
    @Published var customCircleImageOpacity: CGFloat = 0.8 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }

    // ---- 网站圆环自定义图片 ----
    @Published var showCustomImageInWebsiteCircle: Bool = false {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }

    @Published var customWebsiteCircleImagePath: String = "" {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }

    @Published var customWebsiteCircleImageScale: CGFloat = 0.7 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }

    @Published var customWebsiteCircleImageOpacity: CGFloat = 0.8 {
        didSet {
            scheduleSaveSettings()
            CircleRingController.shared.reloadCircleRing()
        }
    }

    // 扇区悬停震动相关设置
    @Published var useSectorHoverHaptic: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var sectorHoverHapticStrength: HapticFeedbackStrength = .medium {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    // 添加在AppSettings类中的属性列表中
    @Published var showRunningIndicator: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var runningIndicatorColor: Color = .blue {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var runningIndicatorSize: Double = 6 {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    @Published var runningIndicatorPosition: ShortcutLabelPosition = .bottom {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    
    // 在AppSettings类中添加一个新的属性，放在其他相似的Toggle属性附近
    @Published var clickAppToToggle: Bool = false {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    // 添加新的布尔属性，放在其他类似的Toggle属性附近
    @Published var clickCircleAppToToggle: Bool = true {
        didSet {
            scheduleSaveSettings()
        }
    }
    
    private let shortcutsKey = "AppShortcuts"
    private let themeKey = "AppTheme"
    private let launchAtLoginKey = "LaunchAtLogin"
    private let usageCountKey = "UsageCount"
    private let iconSizeKey = "IconSize"
    private let appIconSizeKey = "AppIconSize"
    private let webIconSizeKey = "WebIconSize"
    private let appIconsPerRowKey = "AppIconsPerRow"
    private let webIconsPerRowKey = "WebIconsPerRow"
    private let windowPositionKey = "WindowPosition"
    private let iconCornerRadiusKey = "IconCornerRadius"
    private let iconBorderWidthKey = "IconBorderWidth"
    private let iconBorderColorKey = "IconBorderColor"
    private let iconSpacingKey = "iconSpacing"
    private let iconGridSpacingKey = "iconGridSpacing"
    private let iconShadowRadiusKey = "iconShadowRadius"
    private let useIconShadowKey = "UseIconShadow"
    private let useHoverBackgroundKey = "UseHoverBackground"
    private let useHoverAnimationKey = "UseHoverAnimation"
    private let hoverScaleKey = "HoverScale"
    private let hoverAnimationDurationKey = "HoverAnimationDuration"
    private let showAppNameKey = "ShowAppName"
    private let showWebsiteNameKey = "ShowWebsiteName"
    private let appNameFontSizeKey = "AppNameFontSize"
    private let websiteNameFontSizeKey = "WebsiteNameFontSize"
    private let showAppShortcutLabelKey = "ShowAppShortcutLabel"
    private let appShortcutLabelPositionKey = "AppShortcutLabelPosition"
    private let appShortcutLabelBackgroundColorKey = "AppShortcutLabelBackgroundColor"
    private let appShortcutLabelTextColorKey = "AppShortcutLabelTextColor"
    private let appShortcutLabelOffsetXKey = "AppShortcutLabelOffsetX"
    private let appShortcutLabelOffsetYKey = "AppShortcutLabelOffsetY"
    private let appShortcutLabelFontSizeKey = "AppShortcutLabelFontSize"
    private let showWebShortcutLabelKey = "ShowWebShortcutLabel"
    private let webShortcutLabelPositionKey = "WebShortcutLabelPosition"
    private let webShortcutLabelBackgroundColorKey = "WebShortcutLabelBackgroundColor"
    private let webShortcutLabelTextColorKey = "WebShortcutLabelTextColor"
    private let webShortcutLabelOffsetXKey = "WebShortcutLabelOffsetX"
    private let webShortcutLabelOffsetYKey = "WebShortcutLabelOffsetY"
    private let webShortcutLabelFontSizeKey = "WebShortcutLabelFontSize"
    private let switchToLastAppWithOptionClickKey = "SwitchToLastAppWithOptionClick"
    private let lastAppSwitchTriggerKey = "LastAppSwitchTrigger"
    private let optionKeyActivationModeKey = "OptionKeyActivationMode"
    private let enableCircleRingModeKey = "EnableCircleRingMode"
    private let circleRingDiameterKey = "CircleRingDiameter"
    private let circleRingIconSizeKey = "CircleRingIconSize"
    private let circleRingIconCornerRadiusKey = "CircleRingIconCornerRadius"
    private let circleRingSectorCountKey = "CircleRingSectorCount"
    private let circleRingWebsiteSectorCountKey = "CircleRingWebsiteSectorCount"
    private let circleRingAppsKey = "CircleRingApps"
    private let circleRingWebsitesKey = "CircleRingWebsites"
    private let circleRingThemeKey = "CircleRingTheme"
    private let circleRingBackgroundEffectKey = "CircleRingBackgroundEffect"
    private let circleRingInnerDiameterKey = "CircleRingInnerDiameter"
    private let useSectorHighlightKey = "UseSectorHighlight"
    private let sectorHighlightOpacityKey = "SectorHighlightOpacity"
    private let useSectorHoverSoundKey = "UseSectorHoverSound"
    private let sectorHoverSoundTypeKey = "SectorHoverSoundType"
    private let useCircleRingAnimationKey = "UseCircleRingAnimation"
    private let circleRingLongPressThresholdKey = "CircleRingLongPressThreshold"
    private let circleRingSafeZoneMarginKey = "CircleRingSafeZoneMargin"
    private let circleRingAnimationSpeedKey = "CircleRingAnimationSpeed"
    private let iconAppearAnimationTypeKey = "IconAppearAnimationType"
    private let iconAppearSpeedKey = "IconAppearSpeed"
    private let circleRingOpacityKey = "CircleRingOpacity"
    private let sectorHighlightColorKey = "SectorHighlightColor"
    private let showAppNameInCircleRingKey = "ShowAppNameInCircleRing"
    private let showCustomImageInCircleKey = "ShowCustomImageInCircle"
    private let customCircleImagePathKey = "CustomCircleImagePath"
    private let customCircleImageScaleKey = "CustomCircleImageScale"
    private let customCircleImageOpacityKey = "CustomCircleImageOpacity"
    private let showCustomImageInWebsiteCircleKey = "ShowCustomImageInWebsiteCircle"
    private let customWebsiteCircleImagePathKey = "CustomWebsiteCircleImagePath"
    private let customWebsiteCircleImageScaleKey = "CustomWebsiteCircleImageScale"
    private let customWebsiteCircleImageOpacityKey = "CustomWebsiteCircleImageOpacity"
    private let useSectorHoverHapticKey = "UseSectorHoverHaptic"
    private let sectorHoverHapticStrengthKey = "SectorHoverHapticStrength"
    
    // 图标悬停背景设置键名
    private let iconHoverBackgroundColorKey = "IconHoverBackgroundColor"
    private let iconHoverBackgroundPaddingKey = "IconHoverBackgroundPadding"
    private let iconHoverBackgroundCornerRadiusKey = "IconHoverBackgroundCornerRadius"
    
    // 运行中应用标识设置键名
    private let showRunningIndicatorKey = "showRunningIndicator"
    private let runningIndicatorColorKey = "runningIndicatorColor"
    private let runningIndicatorSizeKey = "runningIndicatorSize"
    private let runningIndicatorPositionKey = "runningIndicatorPosition"
    
    // 在私有键名常量区域添加新的键名
    private let clickAppToToggleKey = "ClickAppToToggle"
    private let clickCircleAppToToggleKey = "ClickCircleAppToToggle"
    
    private init() {
        isInitializing = true
        
        // 加载所有设置
        loadSettings()
        
        // 设置启动登录状态
        launchAtLogin = SMAppService.mainApp.status == .enabled
        
        // 注意：此处之前存在键名不一致问题，导致某些设置无法持久化
        // 已修复所有圆环模式设置的键名，统一为首字母大写格式
        // 并优化了loadSettings方法，确保所有设置项都能正确加载
        
        // 初始化完成，确保将标志设置为false
        optiDebugLog("[AppSettings] 初始化完成")
        isInitializing = false
    }
    
    func loadSettings() {
        optiDebugLog("[AppSettings] 开始加载设置...")
        isInitializing = true

        if let data = UserDefaults.standard.data(forKey: shortcutsKey),
           let shortcuts = try? JSONDecoder().decode([AppShortcut].self, from: data) {
            optiDebugLog("[AppSettings] 加载了 \(shortcuts.count) 个快捷键")
            self.shortcuts = shortcuts
        }
        
        // 加载主题
        if let themeString = UserDefaults.standard.string(forKey: themeKey),
           let theme = Theme(rawValue: themeString) {
            self.theme = theme
        }
        
        // 加载其他布尔值设置
        totalUsageCount = UserDefaults.standard.integer(forKey: usageCountKey)
        if let lastAppSwitchTriggerRawValue = UserDefaults.standard.string(forKey: lastAppSwitchTriggerKey),
           let trigger = LastAppSwitchTrigger(rawValue: lastAppSwitchTriggerRawValue) {
            lastAppSwitchTrigger = trigger
        } else if UserDefaults.standard.contains(key: switchToLastAppWithOptionClickKey) {
            lastAppSwitchTrigger = UserDefaults.standard.bool(forKey: switchToLastAppWithOptionClickKey) ? .option : .disabled
        } else {
            lastAppSwitchTrigger = .rightCommand
            UserDefaults.standard.set(lastAppSwitchTrigger.rawValue, forKey: lastAppSwitchTriggerKey)
        }

        if let optionModeRawValue = UserDefaults.standard.string(forKey: optionKeyActivationModeKey),
           let optionMode = OptionKeyActivationMode(rawValue: optionModeRawValue) {
            optionKeyActivationMode = optionMode
        } else {
            optionKeyActivationMode = .both
            UserDefaults.standard.set(optionKeyActivationMode.rawValue, forKey: optionKeyActivationModeKey)
        }
        
        // 加载数值设置，如果没有则使用默认值
        iconSize = UserDefaults.standard.double(forKey: iconSizeKey)
        if !UserDefaults.standard.contains(key: iconSizeKey) {
            iconSize = 80
            UserDefaults.standard.set(80, forKey: iconSizeKey)
        }
        
        appIconSize = UserDefaults.standard.double(forKey: appIconSizeKey)
        if !UserDefaults.standard.contains(key: appIconSizeKey) {
            appIconSize = 80
            UserDefaults.standard.set(80, forKey: appIconSizeKey)
        }
        
        webIconSize = UserDefaults.standard.double(forKey: webIconSizeKey)
        if !UserDefaults.standard.contains(key: webIconSizeKey) {
            webIconSize = 80
            UserDefaults.standard.set(80, forKey: webIconSizeKey)
        }
        
        
        if let positionString = UserDefaults.standard.string(forKey: windowPositionKey),
           let position = WindowPosition(rawValue: positionString) {
            windowPosition = position
        }
        
        // 加载图标样式设置
        iconCornerRadius = UserDefaults.standard.double(forKey: iconCornerRadiusKey)
        if !UserDefaults.standard.contains(key: iconCornerRadiusKey) {
            iconCornerRadius = 16
            UserDefaults.standard.set(16, forKey: iconCornerRadiusKey)
        }
        
        iconBorderWidth = UserDefaults.standard.double(forKey: iconBorderWidthKey)
        if !UserDefaults.standard.contains(key: iconBorderWidthKey) {
            iconBorderWidth = 2
            UserDefaults.standard.set(2, forKey: iconBorderWidthKey)
        }
        
        if let colorData = UserDefaults.standard.data(forKey: iconBorderColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            iconBorderColor = Color(nsColor: color)
        }
        
        iconSpacing = UserDefaults.standard.double(forKey: iconSpacingKey)
        if !UserDefaults.standard.contains(key: iconSpacingKey) {
            iconSpacing = 4
            UserDefaults.standard.set(4, forKey: iconSpacingKey)
        }
        
        iconGridSpacing = UserDefaults.standard.double(forKey: iconGridSpacingKey)
        if !UserDefaults.standard.contains(key: iconGridSpacingKey) {
            iconGridSpacing = 16
            UserDefaults.standard.set(16, forKey: iconGridSpacingKey)
        }
        
        iconShadowRadius = UserDefaults.standard.double(forKey: iconShadowRadiusKey)
        if !UserDefaults.standard.contains(key: iconShadowRadiusKey) {
            iconShadowRadius = 4
            UserDefaults.standard.set(4, forKey: iconShadowRadiusKey)
        }
        
        useIconShadow = UserDefaults.standard.bool(forKey: useIconShadowKey)
        if !UserDefaults.standard.contains(key: useIconShadowKey) {
            useIconShadow = true
            UserDefaults.standard.set(true, forKey: useIconShadowKey)
        }
        
        // 加载图标悬停背景设置
        if let colorData = UserDefaults.standard.data(forKey: iconHoverBackgroundColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            iconHoverBackgroundColor = Color(color)
        }
        
        iconHoverBackgroundPadding = UserDefaults.standard.double(forKey: iconHoverBackgroundPaddingKey)
        if !UserDefaults.standard.contains(key: iconHoverBackgroundPaddingKey) {
            iconHoverBackgroundPadding = 4
            UserDefaults.standard.set(4, forKey: iconHoverBackgroundPaddingKey)
        }
        
        iconHoverBackgroundCornerRadius = UserDefaults.standard.double(forKey: iconHoverBackgroundCornerRadiusKey)
        if !UserDefaults.standard.contains(key: iconHoverBackgroundCornerRadiusKey) {
            iconHoverBackgroundCornerRadius = 8
            UserDefaults.standard.set(8, forKey: iconHoverBackgroundCornerRadiusKey)
        }
        
        // 加载图标悬停动画设置
        useHoverAnimation = UserDefaults.standard.bool(forKey: useHoverAnimationKey)
        if !UserDefaults.standard.contains(key: useHoverAnimationKey) {
            useHoverAnimation = true
            UserDefaults.standard.set(true, forKey: useHoverAnimationKey)
        }
        
        hoverScale = UserDefaults.standard.double(forKey: hoverScaleKey)
        if !UserDefaults.standard.contains(key: hoverScaleKey) {
            hoverScale = 1.1
            UserDefaults.standard.set(1.1, forKey: hoverScaleKey)
        }
        
        hoverAnimationDuration = UserDefaults.standard.double(forKey: hoverAnimationDurationKey)
        if !UserDefaults.standard.contains(key: hoverAnimationDurationKey) {
            hoverAnimationDuration = 0.2
            UserDefaults.standard.set(0.2, forKey: hoverAnimationDurationKey)
        }
        
        // 加载图标标签设置
        showAppName = UserDefaults.standard.bool(forKey: showAppNameKey)
        if !UserDefaults.standard.contains(key: showAppNameKey) {
            showAppName = true
            UserDefaults.standard.set(true, forKey: showAppNameKey)
        }
        
        showWebsiteName = UserDefaults.standard.bool(forKey: showWebsiteNameKey)
        if !UserDefaults.standard.contains(key: showWebsiteNameKey) {
            showWebsiteName = true
            UserDefaults.standard.set(true, forKey: showWebsiteNameKey)
        }
        
        appNameFontSize = UserDefaults.standard.double(forKey: appNameFontSizeKey)
        if !UserDefaults.standard.contains(key: appNameFontSizeKey) {
            appNameFontSize = 12
            UserDefaults.standard.set(12, forKey: appNameFontSizeKey)
        }
        
        websiteNameFontSize = UserDefaults.standard.double(forKey: websiteNameFontSizeKey)
        if !UserDefaults.standard.contains(key: websiteNameFontSizeKey) {
            websiteNameFontSize = 10
            UserDefaults.standard.set(10, forKey: websiteNameFontSizeKey)
        }
        
        
        // 加载快捷键标签设置
        showAppShortcutLabel = UserDefaults.standard.bool(forKey: showAppShortcutLabelKey)
        appShortcutLabelPosition = ShortcutLabelPosition(rawValue: UserDefaults.standard.string(forKey: appShortcutLabelPositionKey) ?? "bottom") ?? .bottom
        
        if let colorData = UserDefaults.standard.data(forKey: appShortcutLabelBackgroundColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            appShortcutLabelBackgroundColor = Color(nsColor: color)
        } else {
            appShortcutLabelBackgroundColor = Color.black.opacity(0.6)
        }
        
        if let colorData = UserDefaults.standard.data(forKey: appShortcutLabelTextColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            appShortcutLabelTextColor = Color(nsColor: color)
        } else {
            appShortcutLabelTextColor = .white
        }
        
        appShortcutLabelOffsetX = UserDefaults.standard.double(forKey: appShortcutLabelOffsetXKey)
        appShortcutLabelOffsetY = UserDefaults.standard.double(forKey: appShortcutLabelOffsetYKey)
        appShortcutLabelFontSize = UserDefaults.standard.double(forKey: appShortcutLabelFontSizeKey)
        
        showWebShortcutLabel = UserDefaults.standard.bool(forKey: showWebShortcutLabelKey)
        webShortcutLabelPosition = ShortcutLabelPosition(rawValue: UserDefaults.standard.string(forKey: webShortcutLabelPositionKey) ?? "bottom") ?? .bottom
        
        if let colorData = UserDefaults.standard.data(forKey: webShortcutLabelBackgroundColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            webShortcutLabelBackgroundColor = Color(nsColor: color)
        } else {
            webShortcutLabelBackgroundColor = Color.black.opacity(0.6)
        }
        
        if let colorData = UserDefaults.standard.data(forKey: webShortcutLabelTextColorKey),
           let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            webShortcutLabelTextColor = Color(nsColor: color)
        } else {
            webShortcutLabelTextColor = .white
        }
        
        webShortcutLabelOffsetX = UserDefaults.standard.double(forKey: webShortcutLabelOffsetXKey)
        webShortcutLabelOffsetY = UserDefaults.standard.double(forKey: webShortcutLabelOffsetYKey)
        webShortcutLabelFontSize = UserDefaults.standard.double(forKey: webShortcutLabelFontSizeKey)
        
        
        
        // 加载圆环模式设置
        enableCircleRingMode = UserDefaults.standard.bool(forKey: enableCircleRingModeKey)
        
        // 加载圆环主题设置
        if let themeString = UserDefaults.standard.string(forKey: circleRingThemeKey),
           let theme = CircleRingTheme(rawValue: themeString) {
            circleRingTheme = theme
        }

        if let effectString = UserDefaults.standard.string(forKey: circleRingBackgroundEffectKey),
           let effect = CircleRingBackgroundEffect(rawValue: effectString) {
            circleRingBackgroundEffect = effect
        } else if UserDefaults.standard.contains(key: "UseBlurEffectForCircleRing"),
                  !UserDefaults.standard.bool(forKey: "UseBlurEffectForCircleRing") {
            circleRingBackgroundEffect = .solid
        } else {
            circleRingBackgroundEffect = .legacyBlur
            UserDefaults.standard.set(CircleRingBackgroundEffect.legacyBlur.rawValue, forKey: circleRingBackgroundEffectKey)
        }
        
        // 加载长按时间阈值
        circleRingLongPressThreshold = UserDefaults.standard.double(forKey: circleRingLongPressThresholdKey)
        if !UserDefaults.standard.contains(key: circleRingLongPressThresholdKey) {
            circleRingLongPressThreshold = 0
            UserDefaults.standard.set(0, forKey: circleRingLongPressThresholdKey)
        }

        // 加载安全区域边距
        if UserDefaults.standard.contains(key: circleRingSafeZoneMarginKey) {
            circleRingSafeZoneMargin = UserDefaults.standard.double(forKey: circleRingSafeZoneMarginKey)
        } else {
            circleRingSafeZoneMargin = 150
            UserDefaults.standard.set(150, forKey: circleRingSafeZoneMarginKey)
        }
        
        // 加载高亮颜色设置
        if let colorString = UserDefaults.standard.string(forKey: sectorHighlightColorKey), 
           let color = SectorHighlightColorType(rawValue: colorString) {
            sectorHighlightColor = color
        } else {
            sectorHighlightColor = .blue
            UserDefaults.standard.set(SectorHighlightColorType.blue.rawValue, forKey: sectorHighlightColorKey)
        }
        
        // 加载圆环展开动效设置
        useCircleRingAnimation = UserDefaults.standard.bool(forKey: useCircleRingAnimationKey)
        if !UserDefaults.standard.contains(key: useCircleRingAnimationKey) {
            useCircleRingAnimation = true
            UserDefaults.standard.set(true, forKey: useCircleRingAnimationKey)
        }
        
        // 加载圆环展开动效速度
        circleRingAnimationSpeed = UserDefaults.standard.double(forKey: circleRingAnimationSpeedKey)
        if !UserDefaults.standard.contains(key: circleRingAnimationSpeedKey) {
            circleRingAnimationSpeed = 0.2
            UserDefaults.standard.set(0.2, forKey: circleRingAnimationSpeedKey)
        }
        
        // 加载图标显示动效类型
        if let animTypeString = UserDefaults.standard.string(forKey: iconAppearAnimationTypeKey),
           let animType = IconAppearAnimationType(rawValue: animTypeString) {
            iconAppearAnimationType = animType
        } else {
            // 兼容旧版本：如果之前使用了布尔设置，转换为新的枚举类型
            if UserDefaults.standard.bool(forKey: "useIconAppearAnimation") {
                iconAppearAnimationType = .clockwise
            } else {
                iconAppearAnimationType = .none
            }
            // 保存新的枚举值以便将来使用
            UserDefaults.standard.set(iconAppearAnimationType.rawValue, forKey: iconAppearAnimationTypeKey)
        }
        
        // 加载图标显示速度
        iconAppearSpeed = UserDefaults.standard.double(forKey: iconAppearSpeedKey)
        if !UserDefaults.standard.contains(key: iconAppearSpeedKey) {
            iconAppearSpeed = 0.04
            UserDefaults.standard.set(0.04, forKey: iconAppearSpeedKey)
        }

        circleRingOpacity = UserDefaults.standard.double(forKey: circleRingOpacityKey)
        if !UserDefaults.standard.contains(key: circleRingOpacityKey) {
            circleRingOpacity = 0.8
            UserDefaults.standard.set(0.8, forKey: circleRingOpacityKey)
        }
        
        // 加载应用名称显示设置
        showAppNameInCircleRing = UserDefaults.standard.bool(forKey: showAppNameInCircleRingKey)
        if !UserDefaults.standard.contains(key: showAppNameInCircleRingKey) {
            showAppNameInCircleRing = true
            UserDefaults.standard.set(true, forKey: showAppNameInCircleRingKey)
        }
        
        // 加载扇区高亮设置
        useSectorHighlight = UserDefaults.standard.bool(forKey: useSectorHighlightKey)
        if !UserDefaults.standard.contains(key: useSectorHighlightKey) {
            useSectorHighlight = true
            UserDefaults.standard.set(true, forKey: useSectorHighlightKey)
        }
        
        // 加载扇区高亮不透明度
        sectorHighlightOpacity = UserDefaults.standard.double(forKey: sectorHighlightOpacityKey)
        if !UserDefaults.standard.contains(key: sectorHighlightOpacityKey) {
            sectorHighlightOpacity = 1.0
            UserDefaults.standard.set(1.0, forKey: sectorHighlightOpacityKey)
        }
        
        // 加载扇区高亮颜色
        if let colorTypeString = UserDefaults.standard.string(forKey: sectorHighlightColorKey),
           let colorType = SectorHighlightColorType(rawValue: colorTypeString) {
            sectorHighlightColor = colorType
        } else {
            sectorHighlightColor = .blue
            UserDefaults.standard.set(SectorHighlightColorType.blue.rawValue, forKey: sectorHighlightColorKey)
        }
        
        // 加载扇区悬停音效设置
        useSectorHoverSound = UserDefaults.standard.bool(forKey: useSectorHoverSoundKey)
        if !UserDefaults.standard.contains(key: useSectorHoverSoundKey) {
            useSectorHoverSound = true
            UserDefaults.standard.set(true, forKey: useSectorHoverSoundKey)
        }
        
        // 加载扇区悬停音效类型
        if let soundTypeString = UserDefaults.standard.string(forKey: sectorHoverSoundTypeKey),
           let soundType = SectorHoverSoundType(rawValue: soundTypeString) {
            sectorHoverSoundType = soundType
        } else {
            sectorHoverSoundType = .frog
            UserDefaults.standard.set(SectorHoverSoundType.frog.rawValue, forKey: sectorHoverSoundTypeKey)
        }
        
        // 加载圆环应用列表
        if let appsData = UserDefaults.standard.array(forKey: circleRingAppsKey) as? [String] {
            circleRingApps = appsData
            optiDebugLog("[AppSettings] 加载了 \(circleRingApps.count) 个圆环应用")
        } else {
            optiDebugLog("[AppSettings] 未找到已保存的圆环应用")
            circleRingApps = []
        }

        if let websiteIdStrings = UserDefaults.standard.array(forKey: circleRingWebsitesKey) as? [String] {
            circleRingWebsites = websiteIdStrings
            optiDebugLog("[AppSettings] 加载了 \(circleRingWebsites.count) 个圆环网站")
        } else {
            optiDebugLog("[AppSettings] 未找到已保存的圆环网站")
            circleRingWebsites = []
        }
        
        // 加载圆环直径
        circleRingDiameter = UserDefaults.standard.double(forKey: circleRingDiameterKey)
        if !UserDefaults.standard.contains(key: circleRingDiameterKey) {
            circleRingDiameter = 280
            UserDefaults.standard.set(280, forKey: circleRingDiameterKey)
        }
        
        // 加载圆环内径
        circleRingInnerDiameter = UserDefaults.standard.double(forKey: circleRingInnerDiameterKey)
        if !UserDefaults.standard.contains(key: circleRingInnerDiameterKey) {
            circleRingInnerDiameter = 60
            UserDefaults.standard.set(60, forKey: circleRingInnerDiameterKey)
        } else {
            let maximumInnerDiameter = min(480, max(60, circleRingDiameter - 40))
            circleRingInnerDiameter = min(max(circleRingInnerDiameter, 60), maximumInnerDiameter)
        }
        
        // 加载图标大小
        circleRingIconSize = UserDefaults.standard.double(forKey: circleRingIconSizeKey)
        if !UserDefaults.standard.contains(key: circleRingIconSizeKey) {
            circleRingIconSize = 40
            UserDefaults.standard.set(40, forKey: circleRingIconSizeKey)
        }
        
        // 加载图标圆角
        circleRingIconCornerRadius = UserDefaults.standard.double(forKey: circleRingIconCornerRadiusKey)
        if !UserDefaults.standard.contains(key: circleRingIconCornerRadiusKey) {
            circleRingIconCornerRadius = 8
            UserDefaults.standard.set(8, forKey: circleRingIconCornerRadiusKey)
        }
        
        // 加载扇区数量
        circleRingSectorCount = UserDefaults.standard.integer(forKey: circleRingSectorCountKey)
        if !UserDefaults.standard.contains(key: circleRingSectorCountKey) {
            circleRingSectorCount = 6
            UserDefaults.standard.set(6, forKey: circleRingSectorCountKey)
        }

        circleRingWebsiteSectorCount = UserDefaults.standard.integer(forKey: circleRingWebsiteSectorCountKey)
        if !UserDefaults.standard.contains(key: circleRingWebsiteSectorCountKey) {
            circleRingWebsiteSectorCount = 6
            UserDefaults.standard.set(6, forKey: circleRingWebsiteSectorCountKey)
        }
        
        // 加载圆环内圆自定义图片设置
        showCustomImageInCircle = UserDefaults.standard.bool(forKey: showCustomImageInCircleKey)
        customCircleImagePath = UserDefaults.standard.string(forKey: customCircleImagePathKey) ?? ""
        
        customCircleImageScale = CGFloat(UserDefaults.standard.double(forKey: customCircleImageScaleKey))
        if !UserDefaults.standard.contains(key: customCircleImageScaleKey) {
            customCircleImageScale = 0.7
            UserDefaults.standard.set(0.7, forKey: customCircleImageScaleKey)
        }
        
        customCircleImageOpacity = CGFloat(UserDefaults.standard.double(forKey: customCircleImageOpacityKey))
        if !UserDefaults.standard.contains(key: customCircleImageOpacityKey) {
            customCircleImageOpacity = 0.8
            UserDefaults.standard.set(0.8, forKey: customCircleImageOpacityKey)
        }

        // 加载网站圆环内圆自定义图片设置
        showCustomImageInWebsiteCircle = UserDefaults.standard.bool(forKey: showCustomImageInWebsiteCircleKey)
        customWebsiteCircleImagePath = UserDefaults.standard.string(forKey: customWebsiteCircleImagePathKey) ?? ""

        customWebsiteCircleImageScale = CGFloat(UserDefaults.standard.double(forKey: customWebsiteCircleImageScaleKey))
        if !UserDefaults.standard.contains(key: customWebsiteCircleImageScaleKey) {
            customWebsiteCircleImageScale = 0.7
            UserDefaults.standard.set(0.7, forKey: customWebsiteCircleImageScaleKey)
        }

        customWebsiteCircleImageOpacity = CGFloat(UserDefaults.standard.double(forKey: customWebsiteCircleImageOpacityKey))
        if !UserDefaults.standard.contains(key: customWebsiteCircleImageOpacityKey) {
            customWebsiteCircleImageOpacity = 0.8
            UserDefaults.standard.set(0.8, forKey: customWebsiteCircleImageOpacityKey)
        }


        // 加载扇区震动设置
        useSectorHoverHaptic = UserDefaults.standard.bool(forKey: useSectorHoverHapticKey)
        if !UserDefaults.standard.contains(key: useSectorHoverHapticKey) {
            useSectorHoverHaptic = true
            UserDefaults.standard.set(true, forKey: useSectorHoverHapticKey)
        }
        
        // 加载震动强度设置
        if let strengthString = UserDefaults.standard.string(forKey: sectorHoverHapticStrengthKey),
           let strength = HapticFeedbackStrength(rawValue: strengthString) {
            sectorHoverHapticStrength = strength
        } else {
            sectorHoverHapticStrength = .medium
            UserDefaults.standard.set(HapticFeedbackStrength.medium.rawValue, forKey: sectorHoverHapticStrengthKey)
        }
        
        // 添加在AppSettings类中的属性列表中
        showRunningIndicator = UserDefaults.standard.bool(forKey: showRunningIndicatorKey)

        // 加载运行中应用标识颜色
        if let colorHexString = UserDefaults.standard.string(forKey: runningIndicatorColorKey) {
            runningIndicatorColor = Color(hex: colorHexString)
        } else {
            runningIndicatorColor = .blue
            UserDefaults.standard.set("#0000FF", forKey: runningIndicatorColorKey)
        }

        runningIndicatorSize = UserDefaults.standard.double(forKey: runningIndicatorSizeKey)
        if !UserDefaults.standard.contains(key: runningIndicatorSizeKey) {
            runningIndicatorSize = 6.0
            UserDefaults.standard.set(6.0, forKey: runningIndicatorSizeKey)
        }

        runningIndicatorPosition = ShortcutLabelPosition(rawValue: UserDefaults.standard.string(forKey: runningIndicatorPositionKey) ?? "bottom") ?? .bottom
        
        // 加载图标悬停背景启用设置
        useHoverBackground = UserDefaults.standard.bool(forKey: useHoverBackgroundKey)
        if !UserDefaults.standard.contains(key: useHoverBackgroundKey) {
            useHoverBackground = false
            UserDefaults.standard.set(false, forKey: useHoverBackgroundKey)
        }
        
        
        // 在其他布尔类型设置的加载代码后添加
        clickAppToToggle = UserDefaults.standard.bool(forKey: clickAppToToggleKey)
        if !UserDefaults.standard.contains(key: clickAppToToggleKey) {
            clickAppToToggle = true
            UserDefaults.standard.set(true, forKey: clickAppToToggleKey)
        }
        
        clickCircleAppToToggle = UserDefaults.standard.bool(forKey: clickCircleAppToToggleKey)
        if !UserDefaults.standard.contains(key: clickCircleAppToToggleKey) {
            clickCircleAppToToggle = true
            UserDefaults.standard.set(true, forKey: clickCircleAppToToggleKey)
        }
        
        
        // 初始化完成
        optiDebugLog("[AppSettings] 设置加载完成")
    }
    
    func saveSettings() {
        pendingSaveWorkItem?.cancel()
        pendingSaveWorkItem = nil

        // 避免初始化时的保存
        guard !isInitializing else { return }
        
        optiDebugLog("[AppSettings] 开始保存设置...")

        // 保存其他设置
        UserDefaults.standard.set(theme.rawValue, forKey: themeKey)
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: shortcutsKey)
        }
        UserDefaults.standard.set(totalUsageCount, forKey: usageCountKey)
        UserDefaults.standard.set(lastAppSwitchTrigger.rawValue, forKey: lastAppSwitchTriggerKey)
        UserDefaults.standard.set(lastAppSwitchTrigger == .option, forKey: switchToLastAppWithOptionClickKey)
        UserDefaults.standard.set(optionKeyActivationMode.rawValue, forKey: optionKeyActivationModeKey)
        UserDefaults.standard.set(iconSize, forKey: iconSizeKey)
        UserDefaults.standard.set(appIconSize, forKey: appIconSizeKey)
        UserDefaults.standard.set(webIconSize, forKey: webIconSizeKey)
        UserDefaults.standard.set(windowPosition.rawValue, forKey: windowPositionKey)
        UserDefaults.standard.set(iconCornerRadius, forKey: iconCornerRadiusKey)
        UserDefaults.standard.set(iconBorderWidth, forKey: iconBorderWidthKey)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(iconBorderColor), requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: iconBorderColorKey)
        }
        UserDefaults.standard.set(iconSpacing, forKey: iconSpacingKey)
        UserDefaults.standard.set(iconGridSpacing, forKey: iconGridSpacingKey)
        UserDefaults.standard.set(iconShadowRadius, forKey: iconShadowRadiusKey)
        UserDefaults.standard.set(useIconShadow, forKey: useIconShadowKey)
        
        // 保存图标悬停背景设置
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(iconHoverBackgroundColor), requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: iconHoverBackgroundColorKey)
        }
        UserDefaults.standard.set(iconHoverBackgroundPadding, forKey: iconHoverBackgroundPaddingKey)
        UserDefaults.standard.set(iconHoverBackgroundCornerRadius, forKey: iconHoverBackgroundCornerRadiusKey)
        
        // 保存图标悬停动画设置
        UserDefaults.standard.set(useHoverAnimation, forKey: useHoverAnimationKey)
        UserDefaults.standard.set(hoverScale, forKey: hoverScaleKey)
        UserDefaults.standard.set(hoverAnimationDuration, forKey: hoverAnimationDurationKey)
        
        // 保存图标标签设置
        UserDefaults.standard.set(showAppName, forKey: showAppNameKey)
        UserDefaults.standard.set(showWebsiteName, forKey: showWebsiteNameKey)
        UserDefaults.standard.set(appNameFontSize, forKey: appNameFontSizeKey)
        UserDefaults.standard.set(websiteNameFontSize, forKey: websiteNameFontSizeKey)
        
        // 保存快捷键标签设置
        UserDefaults.standard.set(showAppShortcutLabel, forKey: showAppShortcutLabelKey)
        UserDefaults.standard.set(appShortcutLabelPosition.rawValue, forKey: appShortcutLabelPositionKey)
        
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(appShortcutLabelBackgroundColor), requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: appShortcutLabelBackgroundColorKey)
        }
        
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(appShortcutLabelTextColor), requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: appShortcutLabelTextColorKey)
        }
        
        UserDefaults.standard.set(appShortcutLabelOffsetX, forKey: appShortcutLabelOffsetXKey)
        UserDefaults.standard.set(appShortcutLabelOffsetY, forKey: appShortcutLabelOffsetYKey)
        UserDefaults.standard.set(appShortcutLabelFontSize, forKey: appShortcutLabelFontSizeKey)
        
        UserDefaults.standard.set(showWebShortcutLabel, forKey: showWebShortcutLabelKey)
        UserDefaults.standard.set(webShortcutLabelPosition.rawValue, forKey: webShortcutLabelPositionKey)
        
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(webShortcutLabelBackgroundColor), requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: webShortcutLabelBackgroundColorKey)
        }
        
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(webShortcutLabelTextColor), requiringSecureCoding: false) {
            UserDefaults.standard.set(colorData, forKey: webShortcutLabelTextColorKey)
        }
        
        UserDefaults.standard.set(webShortcutLabelOffsetX, forKey: webShortcutLabelOffsetXKey)
        UserDefaults.standard.set(webShortcutLabelOffsetY, forKey: webShortcutLabelOffsetYKey)
        UserDefaults.standard.set(webShortcutLabelFontSize, forKey: webShortcutLabelFontSizeKey)
        
        
        // 保存圆环模式设置
        UserDefaults.standard.set(enableCircleRingMode, forKey: enableCircleRingModeKey)
        UserDefaults.standard.set(circleRingDiameter, forKey: circleRingDiameterKey)
        UserDefaults.standard.set(circleRingIconSize, forKey: circleRingIconSizeKey)
        UserDefaults.standard.set(circleRingIconCornerRadius, forKey: circleRingIconCornerRadiusKey)
        UserDefaults.standard.set(circleRingSectorCount, forKey: circleRingSectorCountKey)
        UserDefaults.standard.set(circleRingWebsiteSectorCount, forKey: circleRingWebsiteSectorCountKey)
        UserDefaults.standard.set(circleRingApps, forKey: circleRingAppsKey)
        optiDebugLog("[AppSettings] 保存 \(circleRingApps.count) 个圆环应用: \(circleRingApps)")
        UserDefaults.standard.set(circleRingWebsites, forKey: circleRingWebsitesKey)
        optiDebugLog("[AppSettings] 保存 \(circleRingWebsites.count) 个圆环网站: \(circleRingWebsites)")
        UserDefaults.standard.set(circleRingTheme.rawValue, forKey: circleRingThemeKey)
        UserDefaults.standard.set(circleRingBackgroundEffect.rawValue, forKey: circleRingBackgroundEffectKey)
        UserDefaults.standard.set(circleRingInnerDiameter, forKey: circleRingInnerDiameterKey)
        UserDefaults.standard.set(useSectorHighlight, forKey: useSectorHighlightKey)
        UserDefaults.standard.set(sectorHighlightOpacity, forKey: sectorHighlightOpacityKey)
        UserDefaults.standard.set(useSectorHoverSound, forKey: useSectorHoverSoundKey)
        UserDefaults.standard.set(sectorHoverSoundType.rawValue, forKey: sectorHoverSoundTypeKey)
        UserDefaults.standard.set(useCircleRingAnimation, forKey: useCircleRingAnimationKey)
        UserDefaults.standard.set(circleRingLongPressThreshold, forKey: circleRingLongPressThresholdKey)
        UserDefaults.standard.set(circleRingSafeZoneMargin, forKey: circleRingSafeZoneMarginKey)
        UserDefaults.standard.set(circleRingAnimationSpeed, forKey: circleRingAnimationSpeedKey)
        UserDefaults.standard.set(iconAppearAnimationType.rawValue, forKey: iconAppearAnimationTypeKey)
        UserDefaults.standard.set(iconAppearSpeed, forKey: iconAppearSpeedKey)
        UserDefaults.standard.set(circleRingOpacity, forKey: circleRingOpacityKey)
        UserDefaults.standard.set(sectorHighlightColor.rawValue, forKey: sectorHighlightColorKey)
        UserDefaults.standard.set(showAppNameInCircleRing, forKey: showAppNameInCircleRingKey)
        UserDefaults.standard.set(showCustomImageInCircle, forKey: showCustomImageInCircleKey)
        UserDefaults.standard.set(customCircleImagePath, forKey: customCircleImagePathKey)
        UserDefaults.standard.set(customCircleImageScale, forKey: customCircleImageScaleKey)
        UserDefaults.standard.set(customCircleImageOpacity, forKey: customCircleImageOpacityKey)
        UserDefaults.standard.set(showCustomImageInWebsiteCircle, forKey: showCustomImageInWebsiteCircleKey)
        UserDefaults.standard.set(customWebsiteCircleImagePath, forKey: customWebsiteCircleImagePathKey)
        UserDefaults.standard.set(customWebsiteCircleImageScale, forKey: customWebsiteCircleImageScaleKey)
        UserDefaults.standard.set(customWebsiteCircleImageOpacity, forKey: customWebsiteCircleImageOpacityKey)
        UserDefaults.standard.set(useSectorHoverHaptic, forKey: useSectorHoverHapticKey)
        UserDefaults.standard.set(sectorHoverHapticStrength.rawValue, forKey: sectorHoverHapticStrengthKey)
        UserDefaults.standard.set(showRunningIndicator, forKey: showRunningIndicatorKey)
        UserDefaults.standard.set(runningIndicatorColor.toHexString(), forKey: runningIndicatorColorKey)
        UserDefaults.standard.set(runningIndicatorSize, forKey: runningIndicatorSizeKey)
        UserDefaults.standard.set(runningIndicatorPosition.rawValue, forKey: runningIndicatorPositionKey)
        UserDefaults.standard.set(useHoverBackground, forKey: useHoverBackgroundKey)
        
        // 在其他布尔类型设置的保存代码后添加
        UserDefaults.standard.set(clickAppToToggle, forKey: clickAppToToggleKey)
        UserDefaults.standard.set(clickCircleAppToToggle, forKey: clickCircleAppToToggleKey)
        
        
        // 发布设置更改通知
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
        
        optiDebugLog("[AppSettings] 设置保存完成")
    }

    func scheduleSaveSettings() {
        guard !isInitializing else { return }

        pendingSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingSaveWorkItem = nil
            self?.saveSettings()
        }
        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + saveDebounceInterval,
            execute: workItem
        )
    }
    
    func incrementUsageCount(type: UsageType = .unknown) {
        totalUsageCount += 1
        UserDefaults.standard.set(totalUsageCount, forKey: usageCountKey)
    }
    
    func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            optiDebugLog("Failed to toggle launch at login: \(error)")
            // 恢复状态
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    // 添加一个重置丢失设置到默认值的方法
    func ensureDefaultSettings() {
        // 如果检测到关键设置丢失，则重置为默认值
        optiDebugLog("[AppSettings] 检查并确保默认设置存在")
        
        // 检查图标尺寸设置
        if iconSize <= 0 {
            optiDebugLog("[AppSettings] 警告：图标尺寸数据无效，重置为默认值")
            iconSize = 48
            UserDefaults.standard.set(48, forKey: iconSizeKey)
        }
        
        if appIconSize <= 0 {
            optiDebugLog("[AppSettings] 警告：应用图标尺寸数据无效，重置为默认值")
            appIconSize = 48
            UserDefaults.standard.set(48, forKey: appIconSizeKey)
        }
        
        if webIconSize <= 0 {
            optiDebugLog("[AppSettings] 警告：网站图标尺寸数据无效，重置为默认值")
            webIconSize = 48
            UserDefaults.standard.set(48, forKey: webIconSizeKey)
        }
        
        // 检查圆环设置
        if circleRingDiameter <= 0 {
            optiDebugLog("[AppSettings] 重置无效的圆环直径设置")
            circleRingDiameter = 280
            UserDefaults.standard.set(280, forKey: circleRingDiameterKey)
        }
        
        if circleRingIconSize <= 0 {
            optiDebugLog("[AppSettings] 警告：圆环图标尺寸数据无效，重置为默认值")
            circleRingIconSize = 40
            UserDefaults.standard.set(40, forKey: circleRingIconSizeKey)
        }
        
        // 确保运行中应用标识设置存在
        if UserDefaults.standard.object(forKey: showRunningIndicatorKey) == nil {
            UserDefaults.standard.set(true, forKey: showRunningIndicatorKey)
            showRunningIndicator = true
        }
        
        if UserDefaults.standard.object(forKey: runningIndicatorSizeKey) == nil {
            UserDefaults.standard.set(6.0, forKey: runningIndicatorSizeKey)
            runningIndicatorSize = 6.0
        }
        
        if UserDefaults.standard.object(forKey: runningIndicatorPositionKey) == nil {
            UserDefaults.standard.set("bottom", forKey: runningIndicatorPositionKey)
            runningIndicatorPosition = .bottom
        }
        
        if UserDefaults.standard.object(forKey: runningIndicatorColorKey) == nil {
            UserDefaults.standard.set("#0000FF", forKey: runningIndicatorColorKey)
            runningIndicatorColor = .blue
        }
        
        // 将更改保存到磁盘
        saveSettings()
    }
}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

// 添加Color扩展，提供十六进制字符串转换功能
extension Color {
    func toHexString() -> String {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            return "#000000"
        }
        
        let red = Int(round(rgbColor.redComponent * 255.0))
        let green = Int(round(rgbColor.greenComponent * 255.0))
        let blue = Int(round(rgbColor.blueComponent * 255.0))
        let alpha = Int(round(rgbColor.alphaComponent * 255.0))
        
        if alpha == 255 {
            return String(format: "#%02X%02X%02X", red, green, blue)
        } else {
            return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
        }
    }
    
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
} 
