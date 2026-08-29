import AppKit
import SwiftUI

enum Language: String, CaseIterable, Identifiable {
    case english = "English"
    case chinese = "中文"
    case japanese = "日本語"
    var id: String { rawValue }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
    var icon: String {
        switch self { case .system: "circle.lefthalf.filled"; case .light: "sun.max.fill"; case .dark: "moon.fill" }
    }
}

struct OmitLang {
    private static let strings: [String: [Language: String]] = [
        "MEMORY": [.english: "Memory", .chinese: "内存", .japanese: "メモリ"],
        "STORAGE": [.english: "Storage", .chinese: "磁盘", .japanese: "ストレージ"],
        "CPU": [.english: "CPU", .chinese: "CPU", .japanese: "CPU"],
        "BATTERY": [.english: "Battery", .chinese: "电池", .japanese: "バッテリー"],
        "NETWORK": [.english: "Network", .chinese: "网络", .japanese: "ネットワーク"],
        "THERMAL": [.english: "Thermal", .chinese: "温度状态", .japanese: "熱状態"],
        "THERMAL_NOMINAL": [.english: "Normal", .chinese: "正常", .japanese: "正常"],
        "THERMAL_FAIR": [.english: "Elevated", .chinese: "偏高", .japanese: "やや高温"],
        "THERMAL_SERIOUS": [.english: "Hot", .chinese: "较热", .japanese: "高温"],
        "THERMAL_CRITICAL": [.english: "Critical", .chinese: "严重", .japanese: "危険な高温"],
        "TRASH": [.english: "Trash", .chinese: "废纸篓", .japanese: "ゴミ箱"],
        "USED": [.english: "Used", .chinese: "已用", .japanese: "使用済み"],
        "TOTAL": [.english: "total", .chinese: "总计", .japanese: "合計"],
        "USAGE": [.english: "Usage", .chinese: "使用率", .japanese: "使用率"],
        "AVAILABLE_SPACE": [.english: "Available Space", .chinese: "可用空间", .japanese: "空き容量"],
        "CHARGING": [.english: "Charging", .chinese: "正在充电", .japanese: "充電中"],
        "FULLY_CHARGED": [.english: "Fully Charged", .chinese: "已充满", .japanese: "充電済み"],
        "EXTERNAL_POWER": [.english: "Power Adapter", .chinese: "电源适配器", .japanese: "電源アダプタ"],
        "ON_BATTERY": [.english: "On Battery", .chinese: "使用电池", .japanese: "バッテリー使用中"],
        "NO_BATTERY": [.english: "Not Available", .chinese: "不可用", .japanese: "利用できません"],
        "DISPLAY_MODULES": [.english: "DISPLAY MODULES", .chinese: "显示模块", .japanese: "表示モジュール"],
        "PREFERENCES": [.english: "PREFERENCES", .chinese: "偏好设置", .japanese: "環境設定"],
        "APPEARANCE": [.english: "APPEARANCE", .chinese: "外观", .japanese: "外観"],
        "SYSTEM": [.english: "System", .chinese: "跟随系统", .japanese: "システム"],
        "LIGHT": [.english: "Light", .chinese: "浅色", .japanese: "ライト"],
        "DARK": [.english: "Dark", .chinese: "深色", .japanese: "ダーク"],
        "LANGUAGE": [.english: "Language", .chinese: "语言", .japanese: "言語"],
        "QUIT": [.english: "Quit Omit", .chinese: "退出 Omit", .japanese: "Omitを終了"],
        "ZEN_MODE": [.english: "All modules are hidden", .chinese: "所有模块均已隐藏", .japanese: "すべてのモジュールが非表示です"],
        "LAUNCH_LOGIN": [.english: "Launch at Login", .chinese: "登录时启动", .japanese: "ログイン時に起動"],
        "DOWNLOAD": [.english: "Download", .chinese: "下行", .japanese: "ダウンロード"],
        "UPLOAD": [.english: "Upload", .chinese: "上行", .japanese: "アップロード"],
        "EMPTY": [.english: "Empty", .chinese: "空", .japanese: "空"],
        "SCANNING": [.english: "Scanning…", .chinese: "正在扫描…", .japanese: "スキャン中…"],
        "NO_ACCESS": [.english: "Authorization needed", .chinese: "需要授权", .japanese: "アクセス許可が必要です"],
        "AUTHORIZE": [.english: "Authorize", .chinese: "授权", .japanese: "許可する"],
        "CLEAR": [.english: "Clear", .chinese: "清空", .japanese: "消去"],
        "CANCEL": [.english: "Cancel", .chinese: "取消", .japanese: "キャンセル"],
        "CONFIRM_CLEAR": [.english: "Clear Trash?", .chinese: "确认清空？", .japanese: "ゴミ箱を空にしますか？"],
        "UNAVAILABLE": [.english: "Unavailable", .chinese: "不可用", .japanese: "利用できません"]
    ]
    static func get(_ key: String, lang: Language) -> String { strings[key]?[lang] ?? key }
}

enum TrashPresentation: Equatable { case unauthorized, empty, content(String), scanning, error(String) }

struct OmitDashboardState {
    var memoryUsed: String
    var memoryTotal: String
    var memoryPercent: Double
    var storageAvailable: String
    var storageUsedPercent: Double
    var cpuValue: String?
    var batteryValue: String?
    var batteryPowerState: BatteryPowerState
    var downloadValue: String
    var uploadValue: String
    var thermalState: ThermalState
    var trash: TrashPresentation
    var cpuTrend: [Double] = []
    var networkDownloadTrend: [Double] = []
    var networkUploadTrend: [Double] = []

    static let standard = OmitDashboardState(
        memoryUsed: "13.8 GB", memoryTotal: "17.2 GB", memoryPercent: 0.80,
        storageAvailable: "219.8 GB", storageUsedPercent: 0.56,
        cpuValue: "24%", batteryValue: "100%", batteryPowerState: .fullyCharged,
        downloadValue: "3 KB/s", uploadValue: "1 KB/s", thermalState: .nominal,
        trash: .content("1.4 GB"),
        cpuTrend: [0.18, 0.24, 0.21, 0.37, 0.31, 0.46, 0.39, 0.52, 0.34, 0.42],
        networkDownloadTrend: [4_000, 18_000, 9_000, 31_000, 17_000, 46_000, 22_000, 37_000, 14_000, 29_000],
        networkUploadTrend: [2_000, 4_000, 3_000, 8_000, 6_000, 11_000, 7_000, 13_000, 5_000, 9_000]
    )
    static let unavailable = OmitDashboardState(memoryUsed: "13.8 GB", memoryTotal: "17.2 GB", memoryPercent: 0.80, storageAvailable: "219.8 GB", storageUsedPercent: 0.56, cpuValue: nil, batteryValue: nil, batteryPowerState: .onBattery, downloadValue: "—", uploadValue: "—", thermalState: .unavailable, trash: .error("Unable to scan"))
}

struct ContentView: View {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var launchManager = LaunchManager()
    @AppStorage("showMemory") private var showMemory = true
    @AppStorage("showStorage") private var showStorage = true
    @AppStorage("showCPU") private var showCPU = true
    @AppStorage("showBattery") private var showBattery = true
    @AppStorage("showNetwork") private var showNetwork = true
    @AppStorage("showThermal") private var showThermal = true
    @AppStorage("showTrash") private var showTrash = true
    @AppStorage("languageRaw") private var languageRaw = Language.chinese.rawValue
    @AppStorage("appearancePreference") private var appearanceRaw = AppAppearance.system.rawValue
    @State private var showSettings = false
    #if DEBUG
    @StateObject private var debugDriver = DebugDashboardDriver()
    @State private var showDebugPanel = false
    #endif

    private var language: Language { Language(rawValue: languageRaw) ?? .chinese }
    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }
    private var liveDashboardState: OmitDashboardState {
        let cpuValue: String?
        switch monitor.cpuState {
        case .unavailable: cpuValue = nil
        case .available(let value, _): cpuValue = value
        }

        let batteryValue: String?
        let batteryPowerState: BatteryPowerState
        switch monitor.batteryState {
        case .noBattery, .unavailable:
            batteryValue = nil
            batteryPowerState = .onBattery
        case .available(let value, let powerState):
            batteryValue = value
            batteryPowerState = powerState
        }

        let downloadValue: String
        let uploadValue: String
        switch monitor.networkState {
        case .unavailable:
            downloadValue = "—"
            uploadValue = "—"
        case .available(let download, let upload, _, _):
            downloadValue = download
            uploadValue = upload
        }

        let trash: TrashPresentation
        switch monitor.trashState {
        case .unauthorized, .staleBookmark: trash = .unauthorized
        case .empty: trash = .empty
        case .content(let value): trash = .content(value)
        case .scanning: trash = .scanning
        case .error(let message): trash = .error(message)
        }

        return OmitDashboardState(
            memoryUsed: monitor.memoryUsedString, memoryTotal: monitor.memoryTotalString, memoryPercent: monitor.memoryPercent,
            storageAvailable: monitor.storageFreeString, storageUsedPercent: monitor.storageUsedPercent,
            cpuValue: cpuValue,
            batteryValue: batteryValue, batteryPowerState: batteryPowerState,
            downloadValue: downloadValue, uploadValue: uploadValue, thermalState: monitor.thermalState, trash: trash,
            cpuTrend: monitor.cpuTrend,
            networkDownloadTrend: monitor.networkDownloadTrend,
            networkUploadTrend: monitor.networkUploadTrend
        )
    }
    private var dashboardState: OmitDashboardState {
        #if DEBUG
        if debugDriver.isEnabled { return debugDriver.dashboardState }
        #endif
        return liveDashboardState
    }
    private var visibleModules: Set<OmitModule> {
        let hasBattery: Bool
        #if DEBUG
        if debugDriver.isEnabled {
            hasBattery = debugDriver.hasBattery
        } else if case .noBattery = monitor.batteryState {
            hasBattery = false
        } else {
            hasBattery = true
        }
        #else
        if case .noBattery = monitor.batteryState { hasBattery = false } else { hasBattery = true }
        #endif
        return DashboardModuleSelection.visibleModules(
            preferences: DashboardModulePreferences(
                showCPU: showCPU,
                showBattery: showBattery,
                showNetwork: showNetwork,
                showThermal: showThermal,
                showTrash: showTrash
            ),
            hasBattery: hasBattery,
            capabilities: .current
        )
    }

    var body: some View {
        OmitPanelContent(
            launchManager: launchManager,
            dashboardState: dashboardState,
            language: language,
            appearance: appearance,
            capabilities: .current,
            visibleModules: visibleModules,
            showMemory: showMemory,
            showStorage: showStorage,
            showSettings: showSettings,
            languageRaw: $languageRaw,
            appearanceRaw: $appearanceRaw,
            onAuthorizeTrash: {
                #if DEBUG
                guard !debugDriver.isEnabled else { return }
                #endif
                monitor.authorizeTrash()
            },
            onClearTrash: {
                #if DEBUG
                guard !debugDriver.isEnabled else { return }
                #endif
                monitor.clearTrash()
            }
        ) {
            showSettings.toggle()
        }
        #if DEBUG
        .overlay(alignment: .topTrailing) {
            Button {
                if showDebugPanel {
                    showDebugPanel = false
                } else {
                    debugDriver.enable()
                    showDebugPanel = true
                }
            } label: {
                Image(systemName: debugDriver.isEnabled ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(debugDriver.isEnabled ? .orange : .secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Debug State Driver")
            .padding(.top, 20)
            .padding(.trailing, 54)
            .popover(isPresented: $showDebugPanel, arrowEdge: .top) {
                DebugDashboardPanel(driver: debugDriver) {
                    debugDriver.restore()
                    showDebugPanel = false
                }
            }
        }
        #endif
        .onAppear { monitor.startMonitoring() }
        .onDisappear { monitor.stopMonitoring() }
    }
}

struct OmitPanelContent: View {
    @ObservedObject var launchManager: LaunchManager
    let dashboardState: OmitDashboardState
    let language: Language
    let appearance: AppAppearance
    let capabilities: ProductCapabilities
    let visibleModules: Set<OmitModule>
    let showMemory: Bool
    let showStorage: Bool
    let showSettings: Bool
    @Binding var languageRaw: String
    @Binding var appearanceRaw: String
    let onAuthorizeTrash: () -> Void
    let onClearTrash: () -> Void
    let onSettings: () -> Void

    var body: some View {
        OmitPanelSurface {
            VStack(spacing: 16) {
                OmitHeader(isShowingSettings: showSettings, onSettings: onSettings)
                if showSettings {
                    SettingsView(launchManager: launchManager, capabilities: capabilities, languageRaw: $languageRaw, appearanceRaw: $appearanceRaw)
                } else {
                    OmitDashboardView(
                        state: dashboardState,
                        language: language,
                        visibleModules: visibleModules,
                        showMemory: showMemory,
                        showStorage: showStorage,
                        onAuthorizeTrash: onAuthorizeTrash,
                        onClearTrash: onClearTrash
                    )
                }
            }
        }
        .omitAppearance(appearance)
    }
}

private struct WindowAppearanceBridge: NSViewRepresentable {
    let appearance: NSAppearance?

    func makeNSView(context: Context) -> AppearanceView {
        let view = AppearanceView(frame: .zero)
        view.targetAppearance = appearance
        return view
    }

    func updateNSView(_ nsView: AppearanceView, context: Context) {
        nsView.targetAppearance = appearance
    }

    final class AppearanceView: NSView {
        var targetAppearance: NSAppearance? {
            didSet { applyAppearanceIfNeeded() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyAppearanceIfNeeded()
        }

        private func applyAppearanceIfNeeded() {
            guard let window, window.appearance?.name != targetAppearance?.name else { return }
            window.appearance = targetAppearance
        }
    }
}

private extension View {
    @ViewBuilder
    func omitAppearance(_ appearance: AppAppearance) -> some View {
        switch appearance {
        case .system:
            background(WindowAppearanceBridge(appearance: nil))
        case .light:
            environment(\.colorScheme, .light)
                .background(WindowAppearanceBridge(appearance: appearance.nsAppearance))
        case .dark:
            environment(\.colorScheme, .dark)
                .background(WindowAppearanceBridge(appearance: appearance.nsAppearance))
        }
    }
}

struct OmitPanelSurface<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content.padding(20).frame(width: 312)
            .background(.ultraThinMaterial).background(Color(nsColor: .windowBackgroundColor).opacity(0.72))
    }
}

struct OmitHeader: View {
    let isShowingSettings: Bool
    let onSettings: () -> Void
    var body: some View {
        HStack {
            Text("Omit.").font(.system(size: 23, weight: .heavy)).tracking(0.4).foregroundStyle(.primary)
            Spacer()
            Button(action: onSettings) {
                Image(systemName: isShowingSettings ? "xmark" : "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.secondary)
                    .frame(width: 28, height: 28).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(isShowingSettings ? "Close Settings" : "Settings")
        }.padding(.horizontal, 2)
    }
}

struct OmitDashboardView: View {
    let state: OmitDashboardState
    let language: Language
    let visibleModules: Set<OmitModule>
    let showMemory: Bool
    let showStorage: Bool
    let onAuthorizeTrash: () -> Void
    let onClearTrash: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            if showMemory {
                PrimaryMetricCard(title: OmitLang.get("MEMORY", lang: language), value: state.memoryUsed, supportingValue: memoryTotalLabel, percentLabel: "\(Int((state.memoryPercent * 100).rounded()))%", percent: state.memoryPercent, icon: "memorychip", accent: .omitMemoryMint, ringEndAccent: .omitMemoryBlueCyan)
            }
            if showStorage {
                PrimaryMetricCard(title: OmitLang.get("STORAGE", lang: language), value: state.storageAvailable, supportingValue: OmitLang.get("AVAILABLE_SPACE", lang: language), percentLabel: "\(Int((state.storageUsedPercent * 100).rounded()))% \(OmitLang.get("USED", lang: language))", percent: state.storageUsedPercent, icon: "internaldrive", accent: .indigo, ringEndAccent: .purple)
            }
            let rows = StatusCardLayoutPlanner.rows(for: visibleModules)
            let showsTrash = visibleModules.contains(.trash)
            if rows.isEmpty && !showsTrash && !showMemory && !showStorage {
                Text(OmitLang.get("ZEN_MODE", lang: language)).font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 96)
            } else {
                ForEach(rows) { row in
                    switch row.style {
                    case .wide:
                        if let module = row.modules.first {
                            wideCard(for: module)
                                .frame(maxWidth: .infinity)
                        }
                    case .pair:
                        HStack(spacing: 12) {
                            ForEach(row.modules) { module in
                                secondaryCard(for: module)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                if showsTrash {
                    TrashCard(status: state.trash, language: language, onAuthorize: onAuthorizeTrash, onClear: onClearTrash)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder private func wideCard(for module: OmitModule) -> some View {
        switch module {
        case .cpu:
            WideCPUCard(state: state, language: language)
        case .battery:
            WideCompactMetricCard(
                title: OmitLang.get("BATTERY", lang: language),
                value: state.batteryValue ?? "—",
                supportingValue: batteryStatusLabel,
                icon: state.batteryPowerState.usesExternalPower ? "battery.100.bolt" : "battery.100",
                iconAccent: .green
            )
        case .network:
            WideNetworkCard(state: state, language: language)
        case .thermal:
            WideThermalStatusCard(state: state.thermalState, language: language)
        case .trash:
            TrashCard(status: state.trash, language: language, onAuthorize: onAuthorizeTrash, onClear: onClearTrash)
        }
    }

    @ViewBuilder private func secondaryCard(for module: OmitModule) -> some View {
        switch module {
        case .cpu:
            CPUCard(state: state, language: language)
        case .battery:
            CompactMetricCard(title: OmitLang.get("BATTERY", lang: language), value: state.batteryValue ?? "—", supportingValue: batteryStatusLabel, icon: state.batteryPowerState.usesExternalPower ? "battery.100.bolt" : "battery.100", iconAccent: .green)
        case .network: NetworkCard(state: state, language: language)
        case .thermal:
            ThermalStatusCard(state: state.thermalState, language: language)
        case .trash: TrashCard(status: state.trash, language: language, onAuthorize: onAuthorizeTrash, onClear: onClearTrash)
        }
    }

    private var memoryTotalLabel: String {
        switch language {
        case .english: "\(state.memoryTotal) \(OmitLang.get("TOTAL", lang: language))"
        case .chinese, .japanese: "\(OmitLang.get("TOTAL", lang: language)) \(state.memoryTotal)"
        }
    }

    private var batteryStatusLabel: String {
        guard state.batteryValue != nil else { return OmitLang.get("UNAVAILABLE", lang: language) }
        let key: String
        switch state.batteryPowerState {
        case .onBattery: key = "ON_BATTERY"
        case .charging: key = "CHARGING"
        case .fullyCharged: key = "FULLY_CHARGED"
        case .externalPower: key = "EXTERNAL_POWER"
        }
        return OmitLang.get(key, lang: language)
    }
}

private extension Color {
    static let omitMemoryMint = Color(red: 0.31, green: 0.91, blue: 0.78)
    static let omitMemoryBlueCyan = Color(red: 0.16, green: 0.57, blue: 0.96)
    static let omitThermalAmber = Color(red: 0.86, green: 0.66, blue: 0.24)
}

private struct CardSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    func body(content: Content) -> some View {
        content.background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(colorScheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.52)))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.07), lineWidth: 0.75))
    }
}

struct PrimaryMetricCard: View {
    let title, value, supportingValue, percentLabel: String
    let percent: Double
    let icon: String
    let accent: Color
    let ringEndAccent: Color
    var body: some View {
        HStack(spacing: 16) {
            MetricRing(percent: percent, icon: icon, accent: accent, endAccent: ringEndAccent)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).lineLimit(2)
                    Spacer(minLength: 4)
                    Text(percentLabel).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(accent).lineLimit(1)
                }
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.82)
                Text(supportingValue).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(2)
            }
        }.padding(14).frame(maxWidth: .infinity, minHeight: 88, alignment: .leading).modifier(CardSurface())
    }
}

struct MetricRing: View {
    let percent: Double
    let icon: String
    let accent: Color
    let endAccent: Color
    var body: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.12), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(max(percent, 0), 1))
                .stroke(
                    AngularGradient(colors: [accent, endAccent, accent], center: .center),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(accent)
        }.frame(width: 58, height: 58).accessibilityHidden(true)
    }
}

struct CompactMetricCard: View {
    let title: String
    let value: String
    let supportingValue: String?
    let icon: String
    let iconAccent: Color
    let valueColor: Color

    init(
        title: String,
        value: String,
        supportingValue: String?,
        icon: String,
        iconAccent: Color,
        valueColor: Color = .primary
    ) {
        self.title = title
        self.value = value
        self.supportingValue = supportingValue
        self.icon = icon
        self.iconAccent = iconAccent
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) { ModuleIcon(icon: icon, accent: iconAccent); Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).lineLimit(2) }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(valueColor).lineLimit(1).minimumScaleFactor(0.75)
                if let supportingValue { Text(supportingValue).font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary).lineLimit(2) }
            }
        }.padding(13).frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading).modifier(CardSurface())
    }
}

struct WideCompactMetricCard: View {
    let title: String
    let value: String
    let supportingValue: String
    let icon: String
    let iconAccent: Color

    var body: some View {
        HStack(spacing: 10) {
            ModuleIcon(icon: icon, accent: iconAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(supportingValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .modifier(CardSurface())
    }
}

private struct MetricSparklineShape: Shape {
    let samples: [Double]
    let maximum: Double

    func path(in rect: CGRect) -> Path {
        guard samples.count >= 2, maximum.isFinite, maximum > 0 else { return Path() }
        var path = Path()
        for (index, sample) in samples.enumerated() {
            let progress = Double(index) / Double(samples.count - 1)
            let normalized = min(max(sample / maximum, 0), 1)
            let point = CGPoint(
                x: rect.minX + rect.width * progress,
                y: rect.maxY - rect.height * normalized
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

private struct MetricSparkline: View {
    let samples: [Double]
    let maximum: Double
    let color: Color

    var body: some View {
        ZStack {
            Color.clear
            if samples.count >= 2 {
                MetricSparklineShape(samples: samples, maximum: maximum)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct NetworkSparklines: View {
    let download: [Double]
    let upload: [Double]

    var body: some View {
        let maximum = NetworkTrendScale.sharedMaximum(download: download, upload: upload)
        ZStack {
            MetricSparkline(samples: upload, maximum: maximum, color: .orange.opacity(0.38))
            MetricSparkline(samples: download, maximum: maximum, color: .orange)
        }
        .accessibilityHidden(true)
    }
}

struct CPUCard: View {
    let state: OmitDashboardState
    let language: Language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ModuleIcon(icon: "cpu", accent: .blue)
                Text(OmitLang.get("CPU", lang: language))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(state.cpuValue ?? "—")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text(state.cpuValue == nil ? OmitLang.get("UNAVAILABLE", lang: language) : OmitLang.get("USAGE", lang: language))
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
            }
            MetricSparkline(samples: state.cpuTrend, maximum: 1, color: .blue)
                .frame(height: 22)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .modifier(CardSurface())
    }
}

struct WideCPUCard: View {
    let state: OmitDashboardState
    let language: Language

    var body: some View {
        HStack(spacing: 10) {
            ModuleIcon(icon: "cpu", accent: .blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(OmitLang.get("CPU", lang: language))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Text(state.cpuValue == nil ? OmitLang.get("UNAVAILABLE", lang: language) : OmitLang.get("USAGE", lang: language))
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            MetricSparkline(samples: state.cpuTrend, maximum: 1, color: .blue)
                .frame(width: 76, height: 28)
            Text(state.cpuValue ?? "—")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .modifier(CardSurface())
    }
}

struct ModuleIcon: View {
    let icon: String; let accent: Color
    var body: some View {
        Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(accent).frame(width: 30, height: 30).background(accent.opacity(0.10), in: Circle()).accessibilityHidden(true)
    }
}

struct ThermalStatusCard: View {
    let state: ThermalState
    let language: Language

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ModuleIcon(icon: "thermometer.medium", accent: .omitThermalAmber)
                Text(OmitLang.get("THERMAL", lang: language))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ThermalStatusIndicator(state: state, language: language)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .modifier(CardSurface())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(OmitLang.get("THERMAL", lang: language)), \(ThermalStatusPresentation.label(for: state, language: language))")
    }
}

private enum ThermalStatusPresentation {
    static func activeLevels(for state: ThermalState) -> Int {
        switch state {
        case .nominal: 1
        case .fair: 2
        case .serious: 3
        case .critical: 4
        case .unavailable: 0
        }
    }

    static func label(for state: ThermalState, language: Language) -> String {
        let key: String
        switch state {
        case .nominal: key = "THERMAL_NOMINAL"
        case .fair: key = "THERMAL_FAIR"
        case .serious: key = "THERMAL_SERIOUS"
        case .critical: key = "THERMAL_CRITICAL"
        case .unavailable: key = "UNAVAILABLE"
        }
        return OmitLang.get(key, lang: language)
    }

    static func color(for state: ThermalState) -> Color {
        switch state {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        case .unavailable: .secondary
        }
    }
}

private struct ThermalStatusIndicator: View {
    let state: ThermalState
    let language: Language

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(segmentColor(at: index))
                        .frame(width: 16, height: 7)
                }
            }
            Text(ThermalStatusPresentation.label(for: state, language: language))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ThermalStatusPresentation.color(for: state))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
    }

    private func segmentColor(at index: Int) -> Color {
        index < ThermalStatusPresentation.activeLevels(for: state)
            ? ThermalStatusPresentation.color(for: state)
            : .secondary.opacity(0.18)
    }
}

struct WideThermalStatusCard: View {
    let state: ThermalState
    let language: Language

    var body: some View {
        HStack(spacing: 10) {
            ModuleIcon(icon: "thermometer.medium", accent: .omitThermalAmber)
            Text(OmitLang.get("THERMAL", lang: language))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 12)
            ThermalStatusIndicator(state: state, language: language)
                .frame(width: 76, alignment: .leading)
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .modifier(CardSurface())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(OmitLang.get("THERMAL", lang: language)), \(ThermalStatusPresentation.label(for: state, language: language))")
    }
}

struct NetworkCard: View {
    let state: OmitDashboardState; let language: Language
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) { ModuleIcon(icon: "wifi", accent: .orange); Text(OmitLang.get("NETWORK", lang: language)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).lineLimit(2) }
            NetworkRow(symbol: "arrow.down", value: state.downloadValue)
            NetworkRow(symbol: "arrow.up", value: state.uploadValue)
            NetworkSparklines(download: state.networkDownloadTrend, upload: state.networkUploadTrend)
                .frame(height: 22)
        }.padding(13).frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading).modifier(CardSurface())
    }
}

struct WideNetworkCard: View {
    let state: OmitDashboardState
    let language: Language

    var body: some View {
        HStack(spacing: 10) {
            ModuleIcon(icon: "wifi", accent: .orange)
            Text(OmitLang.get("NETWORK", lang: language))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 8)
            NetworkSparklines(download: state.networkDownloadTrend, upload: state.networkUploadTrend)
                .frame(width: 62, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                NetworkRow(symbol: "arrow.down", value: state.downloadValue)
                NetworkRow(symbol: "arrow.up", value: state.uploadValue)
            }
            .frame(width: 82, alignment: .leading)
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .modifier(CardSurface())
    }
}

private struct NetworkRow: View {
    let symbol: String
    let value: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(.orange).frame(width: 11)
            Text(normalizedValue).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.72)
        }
    }

    private var normalizedValue: String {
        value
            .replacingOccurrences(of: "bytes/s", with: "B/s")
            .replacingOccurrences(of: "byte/s", with: "B/s")
            .replacingOccurrences(of: "kB/s", with: "KB/s")
    }
}

struct TrashCard: View {
    let status: TrashPresentation; let language: Language; let onAuthorize: () -> Void; let onClear: () -> Void
    @State private var isConfirming: Bool
    init(status: TrashPresentation, language: Language, initiallyConfirming: Bool = false, onAuthorize: @escaping () -> Void, onClear: @escaping () -> Void) {
        self.status = status; self.language = language; self.onAuthorize = onAuthorize; self.onClear = onClear; _isConfirming = State(initialValue: initiallyConfirming)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) { ModuleIcon(icon: "trash", accent: .pink); Text(OmitLang.get("TRASH", lang: language)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).lineLimit(2) }
            if isConfirming { confirmationContent } else { statusContent }
        }.padding(13).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading).modifier(CardSurface())
    }
    @ViewBuilder private var statusContent: some View {
        switch status {
        case .unauthorized:
            Text(OmitLang.get("NO_ACCESS", lang: language)).trashStatusStyle()
            Button(OmitLang.get("AUTHORIZE", lang: language), action: onAuthorize).buttonStyle(CompactActionButtonStyle(tint: .accentColor))
        case .empty: Text(OmitLang.get("EMPTY", lang: language)).trashStatusStyle()
        case .content(let value):
            HStack(alignment: .firstTextBaseline) {
                Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                Button(OmitLang.get("CLEAR", lang: language)) { withAnimation(.easeInOut(duration: 0.15)) { isConfirming = true } }.buttonStyle(CompactActionButtonStyle(tint: .pink))
            }
        case .scanning: Text(OmitLang.get("SCANNING", lang: language)).trashStatusStyle()
        case .error(let message): Text(message).trashStatusStyle()
        }
    }
    private var confirmationContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(OmitLang.get("CONFIRM_CLEAR", lang: language)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.primary).lineLimit(2)
            HStack(spacing: 6) {
                Button(OmitLang.get("CANCEL", lang: language)) { withAnimation(.easeInOut(duration: 0.15)) { isConfirming = false } }.buttonStyle(CompactActionButtonStyle(tint: .secondary))
                Button(OmitLang.get("CLEAR", lang: language)) { isConfirming = false; onClear() }.buttonStyle(CompactActionButtonStyle(tint: .pink))
            }
        }
    }
}

private extension View {
    func trashStatusStyle() -> some View { font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).lineLimit(2) }
}

struct CompactActionButtonStyle: ButtonStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 10, weight: .semibold)).foregroundStyle(tint).padding(.horizontal, 9).frame(minHeight: 26)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.10), in: Capsule()).overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 0.75))
    }
}

struct SettingsView: View {
    @ObservedObject var launchManager: LaunchManager
    let capabilities: ProductCapabilities
    @AppStorage("showMemory") private var showMemory = true
    @AppStorage("showStorage") private var showStorage = true
    @AppStorage("showCPU") private var showCPU = true
    @AppStorage("showBattery") private var showBattery = true
    @AppStorage("showNetwork") private var showNetwork = true
    @AppStorage("showThermal") private var showThermal = true
    @AppStorage("showTrash") private var showTrash = true
    @Binding var languageRaw: String
    @Binding var appearanceRaw: String
    private var language: Language { Language(rawValue: languageRaw) ?? .chinese }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionTitle(OmitLang.get("APPEARANCE", lang: language))
            AppearancePicker(selection: $appearanceRaw, language: language)
            SettingsSectionTitle(OmitLang.get("DISPLAY_MODULES", lang: language))
            VStack(spacing: 0) {
                SettingsToggleRow(title: OmitLang.get("MEMORY", lang: language), icon: "memorychip", isOn: $showMemory); SettingsDivider()
                SettingsToggleRow(title: OmitLang.get("STORAGE", lang: language), icon: "internaldrive", isOn: $showStorage); SettingsDivider()
                SettingsToggleRow(title: OmitLang.get("CPU", lang: language), icon: "cpu", isOn: $showCPU); SettingsDivider()
                SettingsToggleRow(title: OmitLang.get("BATTERY", lang: language), icon: "battery.100", isOn: $showBattery); SettingsDivider()
                SettingsToggleRow(title: OmitLang.get("NETWORK", lang: language), icon: "wifi", isOn: $showNetwork); SettingsDivider()
                SettingsToggleRow(title: OmitLang.get("THERMAL", lang: language), icon: "thermometer.medium", isOn: $showThermal)
                if capabilities.settingsModules.contains(.trash) {
                    SettingsDivider()
                    SettingsToggleRow(title: OmitLang.get("TRASH", lang: language), icon: "trash", isOn: $showTrash)
                }
            }.modifier(CardSurface())
            SettingsSectionTitle(OmitLang.get("PREFERENCES", lang: language))
            VStack(spacing: 0) {
                SettingsToggleRow(title: OmitLang.get("LAUNCH_LOGIN", lang: language), icon: "bolt.fill", isOn: Binding(get: { launchManager.isLaunchAtLoginEnabled }, set: { launchManager.toggleLaunchAtLogin(enabled: $0) })); SettingsDivider()
                HStack {
                    Label(OmitLang.get("LANGUAGE", lang: language), systemImage: "globe").font(.system(size: 12, weight: .medium)); Spacer()
                    Picker("", selection: $languageRaw) { ForEach(Language.allCases) { Text($0.rawValue).tag($0.rawValue) } }.labelsHidden().frame(width: 104)
                }.padding(.horizontal, 12).frame(minHeight: 40)
            }.modifier(CardSurface())
            Button { NSApplication.shared.terminate(nil) } label: {
                Text(OmitLang.get("QUIT", lang: language)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.red).frame(maxWidth: .infinity, minHeight: 32).background(Color.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }.buttonStyle(.plain)
        }
    }
}

struct SettingsSectionTitle: View {
    let text: String; init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary) }
}

struct AppearancePicker: View {
    @Binding var selection: String; let language: Language
    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppAppearance.allCases) { appearance in
                Button { selection = appearance.rawValue } label: {
                    VStack(spacing: 5) { Image(systemName: appearance.icon).font(.system(size: 13, weight: .semibold)); Text(label(for: appearance)).font(.system(size: 10, weight: .semibold)) }
                        .foregroundStyle(selection == appearance.rawValue ? Color.accentColor : Color.secondary).frame(maxWidth: .infinity, minHeight: 50)
                        .background(selection == appearance.rawValue ? Color.accentColor.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(selection == appearance.rawValue ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.padding(5).modifier(CardSurface())
    }
    private func label(for appearance: AppAppearance) -> String {
        switch appearance { case .system: OmitLang.get("SYSTEM", lang: language); case .light: OmitLang.get("LIGHT", lang: language); case .dark: OmitLang.get("DARK", lang: language) }
    }
}

struct SettingsToggleRow: View {
    let title, icon: String; @Binding var isOn: Bool
    var body: some View {
        HStack { Label(title, systemImage: icon).font(.system(size: 12, weight: .medium)).lineLimit(2); Spacer(); Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small) }
            .padding(.horizontal, 12).frame(minHeight: 38)
    }
}
struct SettingsDivider: View { var body: some View { Divider().padding(.leading, 12) } }

private struct DashboardPreview: View {
    let state: OmitDashboardState
    let language: Language
    let colorScheme: ColorScheme
    let capabilities: ProductCapabilities
    var body: some View {
        OmitPanelSurface { VStack(spacing: 16) { OmitHeader(isShowingSettings: false, onSettings: {}); OmitDashboardView(state: state, language: language, visibleModules: capabilities.dashboardModules, showMemory: true, showStorage: true, onAuthorizeTrash: {}, onClearTrash: {}) } }.preferredColorScheme(colorScheme)
    }
}
private struct SettingsPreview: View {
    let colorScheme: ColorScheme
    let capabilities: ProductCapabilities
    @State private var languageRaw = Language.english.rawValue
    @State private var appearanceRaw = AppAppearance.system.rawValue
    @StateObject private var launchManager = LaunchManager()
    var body: some View {
        OmitPanelSurface { VStack(spacing: 16) { OmitHeader(isShowingSettings: true, onSettings: {}); SettingsView(launchManager: launchManager, capabilities: capabilities, languageRaw: $languageRaw, appearanceRaw: $appearanceRaw) } }.preferredColorScheme(colorScheme)
    }
}

private struct ThermalFixturePreview: View {
    let thermalState: ThermalState
    let language: Language
    let colorScheme: ColorScheme

    private var fixtureState: OmitDashboardState {
        var fixture = OmitDashboardState.standard
        fixture.thermalState = thermalState
        return fixture
    }

    var body: some View {
        OmitPanelSurface {
            OmitDashboardView(
                state: fixtureState,
                language: language,
                visibleModules: [.thermal],
                showMemory: false,
                showStorage: false,
                onAuthorizeTrash: {},
                onClearTrash: {}
            )
        }
        .preferredColorScheme(colorScheme)
    }
}

private struct WideStatusFixturePreview: View {
    let module: OmitModule
    let language: Language
    let colorScheme: ColorScheme

    var body: some View {
        OmitPanelSurface {
            OmitDashboardView(
                state: .standard,
                language: language,
                visibleModules: [module],
                showMemory: false,
                showStorage: false,
                onAuthorizeTrash: {},
                onClearTrash: {}
            )
        }
        .preferredColorScheme(colorScheme)
    }
}

private enum TrendFixtureKind: String {
    case justStarted, stable, fluctuating, burst, directional, unavailable, reset

    var state: OmitDashboardState {
        var state = OmitDashboardState.standard
        switch self {
        case .justStarted:
            state.cpuTrend = [0.24]
            state.networkDownloadTrend = [3_000]
            state.networkUploadTrend = [1_000]
        case .stable:
            state.cpuTrend = Array(repeating: 0.28, count: 30)
            state.networkDownloadTrend = Array(repeating: 18_000, count: 30)
            state.networkUploadTrend = Array(repeating: 5_000, count: 30)
        case .fluctuating:
            break
        case .burst:
            state.cpuTrend = [0.12, 0.14, 0.16, 0.18, 0.92, 0.44, 0.21, 0.17]
            state.networkDownloadTrend = [2_000, 3_000, 2_000, 4_000, 240_000, 42_000, 8_000, 3_000]
            state.networkUploadTrend = [1_000, 1_500, 1_000, 2_000, 28_000, 9_000, 3_000, 1_000]
        case .directional:
            state.networkDownloadTrend = [12_000, 42_000, 88_000, 140_000, 96_000, 72_000]
            state.networkUploadTrend = [1_000, 2_000, 3_000, 4_000, 3_000, 2_000]
        case .unavailable:
            state.cpuValue = nil
            state.downloadValue = "—"
            state.uploadValue = "—"
            state.cpuTrend = []
            state.networkDownloadTrend = []
            state.networkUploadTrend = []
        case .reset:
            state.cpuTrend = []
            state.networkDownloadTrend = []
            state.networkUploadTrend = []
        }
        return state
    }
}

private struct TrendFixturePreview: View {
    let kind: TrendFixtureKind
    let modules: Set<OmitModule>
    let colorScheme: ColorScheme

    var body: some View {
        OmitPanelSurface {
            OmitDashboardView(
                state: kind.state,
                language: .english,
                visibleModules: modules,
                showMemory: false,
                showStorage: false,
                onAuthorizeTrash: {},
                onClearTrash: {}
            )
        }
        .preferredColorScheme(colorScheme)
    }
}

struct Omit_Previews: PreviewProvider {
    static var unauthorizedState: OmitDashboardState {
        var state = OmitDashboardState.standard
        state.trash = .unauthorized
        return state
    }
    static var emptyTrashState: OmitDashboardState {
        var state = OmitDashboardState.standard
        state.trash = .empty
        return state
    }
    static var scanningTrashState: OmitDashboardState {
        var state = OmitDashboardState.standard
        state.trash = .scanning
        return state
    }

    static var previews: some View {
        Group {
            DashboardPreview(state: .standard, language: .english, colorScheme: .light, capabilities: .appStore).previewDisplayName("StoreHeroLight")
            DashboardPreview(state: .standard, language: .english, colorScheme: .dark, capabilities: .appStore).previewDisplayName("StoreHeroDark")
            SettingsPreview(colorScheme: .light, capabilities: .appStore).previewDisplayName("StoreAppearanceSettings")
            WideStatusFixturePreview(module: .cpu, language: .english, colorScheme: .light).previewDisplayName("Wide — CPU")
            WideStatusFixturePreview(module: .battery, language: .chinese, colorScheme: .light).previewDisplayName("Wide — Battery")
            WideStatusFixturePreview(module: .network, language: .english, colorScheme: .dark).previewDisplayName("Wide — Network")
            TrendFixturePreview(kind: .justStarted, modules: [.cpu, .battery], colorScheme: .light).previewDisplayName("Trend — Just Started / Compact")
            TrendFixturePreview(kind: .stable, modules: [.cpu], colorScheme: .dark).previewDisplayName("Trend — Stable / CPU Wide")
            TrendFixturePreview(kind: .fluctuating, modules: [.cpu, .network], colorScheme: .light).previewDisplayName("Trend — Fluctuating / Compact")
            TrendFixturePreview(kind: .burst, modules: [.network], colorScheme: .light).previewDisplayName("Trend — Burst / Network Wide")
            TrendFixturePreview(kind: .directional, modules: [.network, .battery], colorScheme: .dark).previewDisplayName("Trend — Download vs Upload")
            TrendFixturePreview(kind: .unavailable, modules: [.cpu, .network], colorScheme: .dark).previewDisplayName("Trend — Unavailable")
            TrendFixturePreview(kind: .reset, modules: [.network], colorScheme: .light).previewDisplayName("Trend — Reset / No Line")
            ThermalFixturePreview(thermalState: .nominal, language: .english, colorScheme: .light).previewDisplayName("Thermal — Nominal / English")
            ThermalFixturePreview(thermalState: .fair, language: .chinese, colorScheme: .light).previewDisplayName("Thermal — Fair / Chinese")
            ThermalFixturePreview(thermalState: .serious, language: .japanese, colorScheme: .dark).previewDisplayName("Thermal — Serious / Japanese")
            ThermalFixturePreview(thermalState: .critical, language: .english, colorScheme: .dark).previewDisplayName("Thermal — Critical")
            ThermalFixturePreview(thermalState: .unavailable, language: .english, colorScheme: .dark).previewDisplayName("Thermal — Unavailable")
            DashboardPreview(state: unauthorizedState, language: .japanese, colorScheme: .light, capabilities: .direct).previewDisplayName("Trash — Unauthorized / Japanese")
            DashboardPreview(state: emptyTrashState, language: .english, colorScheme: .light, capabilities: .direct).previewDisplayName("Trash — Empty")
            DashboardPreview(state: scanningTrashState, language: .english, colorScheme: .dark, capabilities: .direct).previewDisplayName("Trash — Scanning")
            DashboardPreview(state: .unavailable, language: .english, colorScheme: .dark, capabilities: .appStore).previewDisplayName("Unavailable Metrics")
            OmitPanelSurface {
                TrashCard(status: .content("1.4 GB"), language: .english, initiallyConfirming: true, onAuthorize: {}, onClear: {}).frame(width: 130)
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Trash — Confirmation")
        }
    }
}
