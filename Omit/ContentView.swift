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
        "TRASH": [.english: "Trash", .chinese: "废纸篓", .japanese: "ゴミ箱"],
        "USED": [.english: "Used", .chinese: "已用", .japanese: "使用済み"],
        "AVAILABLE_SPACE": [.english: "Available Space", .chinese: "可用空间", .japanese: "空き容量"],
        "CHARGING": [.english: "Charging", .chinese: "充电中", .japanese: "充電中"],
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
        "UPDATED": [.english: "Updated just now", .chinese: "刚刚更新", .japanese: "たった今更新"],
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

enum OmitModule: String, CaseIterable { case cpu, battery, network, trash }
enum TrashPresentation: Equatable { case unauthorized, empty, content(String), scanning, error(String) }

struct OmitDashboardState {
    var memoryUsed: String
    var memoryTotal: String
    var memoryPercent: Double
    var storageAvailable: String
    var storageUsedPercent: Double
    var cpuValue: String?
    var batteryValue: String?
    var batteryIsCharging: Bool
    var downloadValue: String
    var uploadValue: String
    var trash: TrashPresentation
    var updatedLabel: String

    static let standard = OmitDashboardState(memoryUsed: "13.8 GB", memoryTotal: "17.2 GB", memoryPercent: 0.80, storageAvailable: "219.8 GB", storageUsedPercent: 0.56, cpuValue: "24%", batteryValue: "100%", batteryIsCharging: true, downloadValue: "3 KB/s", uploadValue: "1 KB/s", trash: .content("1.4 GB"), updatedLabel: "Updated just now")
    static let unavailable = OmitDashboardState(memoryUsed: "13.8 GB", memoryTotal: "17.2 GB", memoryPercent: 0.80, storageAvailable: "219.8 GB", storageUsedPercent: 0.56, cpuValue: nil, batteryValue: nil, batteryIsCharging: false, downloadValue: "—", uploadValue: "—", trash: .error("Unable to scan"), updatedLabel: "Updated just now")
}

struct ContentView: View {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var launchManager = LaunchManager()
    @AppStorage("showMemory") private var showMemory = true
    @AppStorage("showStorage") private var showStorage = true
    @AppStorage("showCPU") private var showCPU = true
    @AppStorage("showBattery") private var showBattery = true
    @AppStorage("showNetwork") private var showNetwork = true
    @AppStorage("showTrash") private var showTrash = true
    @AppStorage("languageRaw") private var languageRaw = Language.chinese.rawValue
    @AppStorage("appearancePreference") private var appearanceRaw = AppAppearance.system.rawValue
    @State private var showSettings = false

    private var language: Language { Language(rawValue: languageRaw) ?? .chinese }
    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .system }
    private var dashboardState: OmitDashboardState {
        let cpuValue: String?
        switch monitor.cpuState {
        case .unavailable: cpuValue = nil
        case .available(let value): cpuValue = value
        }

        let batteryValue: String?
        let batteryIsCharging: Bool
        switch monitor.batteryState {
        case .noBattery, .unavailable:
            batteryValue = nil
            batteryIsCharging = false
        case .available(let value, let isCharging):
            batteryValue = value
            batteryIsCharging = isCharging
        }

        let downloadValue: String
        let uploadValue: String
        switch monitor.networkState {
        case .unavailable:
            downloadValue = "—"
            uploadValue = "—"
        case .available(let download, let upload):
            downloadValue = download
            uploadValue = upload
        }

        let trash: TrashPresentation
        switch monitor.trashState {
        case .unauthorized: trash = .unauthorized
        case .empty: trash = .empty
        case .content(let value): trash = .content(value)
        case .scanning: trash = .scanning
        case .error(let message): trash = .error(message)
        }

        return OmitDashboardState(
            memoryUsed: monitor.memoryUsedString, memoryTotal: monitor.memoryTotalString, memoryPercent: monitor.memoryPercent,
            storageAvailable: monitor.storageFreeString, storageUsedPercent: monitor.storageUsedPercent,
            cpuValue: cpuValue,
            batteryValue: batteryValue, batteryIsCharging: batteryIsCharging,
            downloadValue: downloadValue, uploadValue: uploadValue, trash: trash,
            updatedLabel: OmitLang.get("UPDATED", lang: language)
        )
    }
    private var visibleModules: Set<OmitModule> {
        var modules = Set<OmitModule>()
        if showCPU { modules.insert(.cpu) }; if showBattery { modules.insert(.battery) }
        if showNetwork { modules.insert(.network) }; if showTrash { modules.insert(.trash) }
        return modules
    }

    var body: some View {
        OmitPanelContent(
            launchManager: launchManager,
            dashboardState: dashboardState,
            language: language,
            appearance: appearance,
            visibleModules: visibleModules,
            showMemory: showMemory,
            showStorage: showStorage,
            showSettings: showSettings,
            languageRaw: $languageRaw,
            appearanceRaw: $appearanceRaw
        ) {
            showSettings.toggle()
        }
        .onAppear { monitor.startMonitoring() }
        .onDisappear { monitor.stopMonitoring() }
    }
}

struct OmitPanelContent: View {
    @ObservedObject var launchManager: LaunchManager
    let dashboardState: OmitDashboardState
    let language: Language
    let appearance: AppAppearance
    let visibleModules: Set<OmitModule>
    let showMemory: Bool
    let showStorage: Bool
    let showSettings: Bool
    @Binding var languageRaw: String
    @Binding var appearanceRaw: String
    let onSettings: () -> Void

    var body: some View {
        OmitPanelSurface {
            VStack(spacing: 16) {
                OmitHeader(isShowingSettings: showSettings, onSettings: onSettings)
                if showSettings {
                    SettingsView(launchManager: launchManager, languageRaw: $languageRaw, appearanceRaw: $appearanceRaw)
                } else {
                    OmitDashboardView(state: dashboardState, language: language, visibleModules: visibleModules, showMemory: showMemory, showStorage: showStorage, onAuthorizeTrash: {}, onClearTrash: {})
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
                PrimaryMetricCard(title: OmitLang.get("MEMORY", lang: language), value: state.memoryUsed, supportingValue: "\(OmitLang.get("USED", lang: language)) / \(state.memoryTotal)", percentLabel: "\(Int((state.memoryPercent * 100).rounded()))%", percent: state.memoryPercent, icon: "memorychip", accent: .mint)
            }
            if showStorage {
                PrimaryMetricCard(title: OmitLang.get("STORAGE", lang: language), value: state.storageAvailable, supportingValue: OmitLang.get("AVAILABLE_SPACE", lang: language), percentLabel: "\(Int((state.storageUsedPercent * 100).rounded()))% \(OmitLang.get("USED", lang: language))", percent: state.storageUsedPercent, icon: "internaldrive", accent: .indigo)
            }
            let modules = OmitModule.allCases.filter(visibleModules.contains)
            if modules.isEmpty && !showMemory && !showStorage {
                Text(OmitLang.get("ZEN_MODE", lang: language)).font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 96)
            } else if !modules.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(modules, id: \.self) { secondaryCard(for: $0) }
                }
            }
            Text(state.updatedLabel).font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary).frame(maxWidth: .infinity).padding(.top, 2)
        }
    }
    @ViewBuilder private func secondaryCard(for module: OmitModule) -> some View {
        switch module {
        case .cpu:
            CompactMetricCard(title: OmitLang.get("CPU", lang: language), value: state.cpuValue ?? "—", supportingValue: state.cpuValue == nil ? OmitLang.get("UNAVAILABLE", lang: language) : nil, icon: "cpu", accent: .blue)
        case .battery:
            CompactMetricCard(title: OmitLang.get("BATTERY", lang: language), value: state.batteryValue ?? "—", supportingValue: state.batteryValue == nil ? OmitLang.get("NO_BATTERY", lang: language) : OmitLang.get(state.batteryIsCharging ? "CHARGING" : "ON_BATTERY", lang: language), icon: state.batteryIsCharging ? "battery.100.bolt" : "battery.100", accent: .green)
        case .network: NetworkCard(state: state, language: language)
        case .trash: TrashCard(status: state.trash, language: language, onAuthorize: onAuthorizeTrash, onClear: onClearTrash)
        }
    }
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
    var body: some View {
        HStack(spacing: 16) {
            MetricRing(percent: percent, icon: icon, accent: accent)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).lineLimit(2)
                    Spacer(minLength: 4)
                    Text(percentLabel).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(accent).fixedSize(horizontal: true, vertical: false)
                }
                Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.82)
                Text(supportingValue).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(2)
            }
        }.padding(14).frame(maxWidth: .infinity, minHeight: 88, alignment: .leading).modifier(CardSurface())
    }
}

struct MetricRing: View {
    let percent: Double; let icon: String; let accent: Color
    var body: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.12), lineWidth: 7)
            Circle().trim(from: 0, to: min(max(percent, 0), 1)).stroke(accent.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
            Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(accent)
        }.frame(width: 58, height: 58).accessibilityHidden(true)
    }
}

struct CompactMetricCard: View {
    let title, value: String; let supportingValue: String?; let icon: String; let accent: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) { ModuleIcon(icon: icon, accent: accent); Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).lineLimit(2) }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 19, weight: .bold, design: .rounded)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.75)
                if let supportingValue { Text(supportingValue).font(.system(size: 10, weight: .medium)).foregroundStyle(.tertiary).lineLimit(2) }
            }
        }.padding(13).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading).modifier(CardSurface())
    }
}

struct ModuleIcon: View {
    let icon: String; let accent: Color
    var body: some View {
        Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(accent).frame(width: 30, height: 30).background(accent.opacity(0.12), in: Circle()).accessibilityHidden(true)
    }
}

struct NetworkCard: View {
    let state: OmitDashboardState; let language: Language
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) { ModuleIcon(icon: "wifi", accent: .orange); Text(OmitLang.get("NETWORK", lang: language)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).lineLimit(2) }
            NetworkRow(symbol: "arrow.down", label: OmitLang.get("DOWNLOAD", lang: language), value: state.downloadValue)
            NetworkRow(symbol: "arrow.up", label: OmitLang.get("UPLOAD", lang: language), value: state.uploadValue)
        }.padding(13).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading).modifier(CardSurface())
    }
}

private struct NetworkRow: View {
    let symbol, label, value: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(.orange).frame(width: 10)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 3)
            Text(value).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.72)
        }
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
    @AppStorage("showMemory") private var showMemory = true
    @AppStorage("showStorage") private var showStorage = true
    @AppStorage("showCPU") private var showCPU = true
    @AppStorage("showBattery") private var showBattery = true
    @AppStorage("showNetwork") private var showNetwork = true
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
                SettingsToggleRow(title: OmitLang.get("TRASH", lang: language), icon: "trash", isOn: $showTrash)
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
    let state: OmitDashboardState; let language: Language; let colorScheme: ColorScheme
    var body: some View {
        OmitPanelSurface { VStack(spacing: 16) { OmitHeader(isShowingSettings: false, onSettings: {}); OmitDashboardView(state: state, language: language, visibleModules: Set(OmitModule.allCases), showMemory: true, showStorage: true, onAuthorizeTrash: {}, onClearTrash: {}) } }.preferredColorScheme(colorScheme)
    }
}
private struct SettingsPreview: View {
    let colorScheme: ColorScheme
    @State private var languageRaw = Language.english.rawValue
    @State private var appearanceRaw = AppAppearance.system.rawValue
    @StateObject private var launchManager = LaunchManager()
    var body: some View {
        OmitPanelSurface { VStack(spacing: 16) { OmitHeader(isShowingSettings: true, onSettings: {}); SettingsView(launchManager: launchManager, languageRaw: $languageRaw, appearanceRaw: $appearanceRaw) } }.preferredColorScheme(colorScheme)
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
            DashboardPreview(state: .standard, language: .english, colorScheme: .light).previewDisplayName("Main — Light")
            DashboardPreview(state: .standard, language: .english, colorScheme: .dark).previewDisplayName("Main — Dark")
            SettingsPreview(colorScheme: .light).previewDisplayName("Settings — Light / System")
            SettingsPreview(colorScheme: .dark).previewDisplayName("Settings — Dark / System")
            DashboardPreview(state: unauthorizedState, language: .japanese, colorScheme: .light).previewDisplayName("Trash — Unauthorized / Japanese")
            DashboardPreview(state: emptyTrashState, language: .english, colorScheme: .light).previewDisplayName("Trash — Empty")
            DashboardPreview(state: scanningTrashState, language: .english, colorScheme: .dark).previewDisplayName("Trash — Scanning")
            DashboardPreview(state: .unavailable, language: .english, colorScheme: .dark).previewDisplayName("Unavailable Metrics")
            OmitPanelSurface {
                TrashCard(status: .content("1.4 GB"), language: .english, initiallyConfirming: true, onAuthorize: {}, onClear: {}).frame(width: 130)
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Trash — Confirmation")
        }
    }
}
