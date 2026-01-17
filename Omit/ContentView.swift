//
//  ContentView.swift
//  Omit
//
//  Created by heisyoudan on 2026/1/16.
//

import SwiftUI
import Charts

// --- 1. 多语言管理器 ---
enum Language: String, CaseIterable, Identifiable {
    case english = "English"
    case chinese = "中文"
    case japanese = "日本語"
    var id: String { self.rawValue }
}

struct OmitLang {
    static func get(_ key: String, lang: Language) -> String {
        let dict: [String: [Language: String]] = [
            // 基础词条
            "MEMORY": [.english: "MEMORY", .chinese: "内存", .japanese: "メモリ"],
            "STORAGE": [.english: "STORAGE", .chinese: "硬盘", .japanese: "ストレージ"],
            "CPU_LOAD": [.english: "CPU LOAD", .chinese: "CPU 负载", .japanese: "CPU 負荷"],
            "BATTERY": [.english: "BATTERY", .chinese: "电池", .japanese: "バッテリー"],
            "DOWNLOAD": [.english: "DOWNLOAD", .chinese: "下载", .japanese: "ダウンロード"],
            "TRASH_BIN": [.english: "TRASH BIN", .chinese: "废纸篓", .japanese: "ゴミ箱"],
            "USED_OF": [.english: "Active /", .chinese: "活跃 /", .japanese: "アクティブ /"],
            "FREE_SPACE": [.english: "Free Space", .chinese: "剩余空间", .japanese: "空き容量"],
            "DISPLAY_MODULES": [.english: "DISPLAY MODULES", .chinese: "显示模块", .japanese: "表示モジュール"],
            "PREFERENCES": [.english: "PREFERENCES", .chinese: "偏好设置", .japanese: "環境設定"],
            "LANGUAGE": [.english: "Language", .chinese: "语言", .japanese: "言語"],
            "QUIT": [.english: "Quit Omit", .chinese: "退出 Omit", .japanese: "Omitを終了"],
            "ZEN_MODE": [.english: "Zen Mode", .chinese: "禅模式", .japanese: "禅モード"],
            "LAUNCH_LOGIN": [.english: "Launch at Login", .chinese: "开机自启", .japanese: "ログイン時に起動"],
            
            // 权限引导词条
            "PERM_TITLE": [.english: "Permission Required", .chinese: "需要权限", .japanese: "権限が必要です"],
            "PERM_DESC": [.english: "To monitor trash size, Omit needs Full Disk Access.", .chinese: "为了监控废纸篓，Omit 需要完全磁盘访问权限。", .japanese: "ゴミ箱を監視するには、フルディスクアクセスが必要です。"],
            "PERM_BTN": [.english: "Open System Settings", .chinese: "打开系统设置", .japanese: "システム設定を開く"],
            "PERM_HINT": [.english: "Go to Privacy & Security > Full Disk Access > Toggle Omit ON", .chinese: "前往 隐私与安全性 > 完全磁盘访问权限 > 开启 Omit", .japanese: "プライバシーとセキュリティ > フルディスクアクセス > Omit をオン"]
        ]
        return dict[key]?[lang] ?? key
    }
}

// 模块枚举
enum OmitModule: String, CaseIterable {
    case cpu, battery, network, trash
}

struct ContentView: View {
    @StateObject private var monitor = SystemMonitor()
    @StateObject private var launchManager = LaunchManager() // [新增] 启动管理器
    
    // 存储设置
    @AppStorage("showMemory") private var showMemory = true
    @AppStorage("showStorage") private var showStorage = true
    @AppStorage("showCPU") private var showCPU = true
    @AppStorage("showBattery") private var showBattery = true
    @AppStorage("showNetwork") private var showNetwork = true
    @AppStorage("showTrash") private var showTrash = true
    
    // 语言设置
    @AppStorage("languageRaw") private var languageRaw = Language.chinese.rawValue
    var language: Language { Language(rawValue: languageRaw) ?? .chinese }
    
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 16) {
            
            // --- Header ---
            HStack {
                Text("Omit.")
                    .font(.system(size: 20, weight: .heavy, design: .default))
                    .tracking(1)
                    .foregroundStyle(.primary.opacity(0.8))
                
                Spacer()
                
                Button {
                    withAnimation(.snappy) { showSettings.toggle() }
                } label: {
                    Image(systemName: showSettings ? "xmark.circle.fill" : "slider.horizontal.3")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
            
            // --- Content ---
            if showSettings {
                SettingsView(launchManager: launchManager, languageRaw: $languageRaw)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                // [权限检测] 如果没有权限，显示引导卡片
                if !monitor.hasTrashPermission {
                    PermissionGuideView(language: language)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // 正常内容
                    VStack(spacing: 12) {
                        
                        // 1. 核心层
                        if showMemory {
                            OmitCard(
                                title: OmitLang.get("MEMORY", lang: language),
                                value: monitor.memoryUsedString,
                                subValue: "\(OmitLang.get("USED_OF", lang: language)) \(monitor.memoryTotalString)",
                                percent: monitor.memoryPercent,
                                icon: "memorychip",
                                color: .mint
                            )
                        }
                        if showStorage {
                            OmitCard(
                                title: OmitLang.get("STORAGE", lang: language),
                                value: monitor.storageFreeString,
                                subValue: OmitLang.get("FREE_SPACE", lang: language),
                                percent: monitor.storageUsedPercent,
                                icon: "internaldrive",
                                color: .indigo
                            )
                        }
                        
                        // 2. 动态流动层
                        let activeModules = getActiveModules()
                        
                        if activeModules.count == 1 { renderWide(activeModules[0]) }
                        else if activeModules.count == 2 {
                            HStack(spacing: 12) { renderSmall(activeModules[0]); renderSmall(activeModules[1]) }
                        }
                        else if activeModules.count == 3 {
                            renderWide(activeModules[0])
                            HStack(spacing: 12) { renderSmall(activeModules[1]); renderSmall(activeModules[2]) }
                        }
                        else if activeModules.count == 4 {
                            HStack(spacing: 12) { renderSmall(activeModules[0]); renderSmall(activeModules[1]) }
                            HStack(spacing: 12) { renderSmall(activeModules[2]); renderSmall(activeModules[3]) }
                        }
                        
                        // Zen Mode
                        if !showMemory && !showStorage && activeModules.isEmpty {
                            Text(OmitLang.get("ZEN_MODE", lang: language))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .frame(height: 100)
                        }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            
            // --- Footer ---
            Spacer().frame(height: 4)
        }
        .padding(20)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
        .background(VisualEffectBlur().ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            monitor.updateStats() // 启动时刷新
        }
    }
    
    // --- 逻辑助手 ---
    
    func getActiveModules() -> [OmitModule] {
        var modules: [OmitModule] = []
        if showCPU { modules.append(.cpu) }
        if showBattery { modules.append(.battery) }
        if showNetwork { modules.append(.network) }
        if showTrash { modules.append(.trash) }
        return modules
    }
    
    @ViewBuilder
    func renderWide(_ module: OmitModule) -> some View {
        switch module {
        case .cpu:
            OmitWideCard(title: OmitLang.get("CPU_LOAD", lang: language), value: monitor.cpuLoadString, icon: "cpu", color: .blue)
        case .battery:
            OmitWideCard(title: OmitLang.get("BATTERY", lang: language), value: monitor.batteryPercentString, icon: monitor.batteryIcon, color: monitor.batteryColor)
        case .network:
            OmitWideCard(title: OmitLang.get("DOWNLOAD", lang: language), value: monitor.networkSpeedString, icon: "wifi", color: .orange)
        case .trash:
            OmitWideCard(title: OmitLang.get("TRASH_BIN", lang: language), value: monitor.trashSizeString, icon: "trash", color: .pink)
                .contentShape(Rectangle())
                .onTapGesture { monitor.emptyTrashAction() }
        }
    }
    
    @ViewBuilder
    func renderSmall(_ module: OmitModule) -> some View {
        switch module {
        case .cpu:
            OmitSmallCard(title: OmitLang.get("CPU_LOAD", lang: language), value: monitor.cpuLoadString, icon: "cpu", color: .blue)
        case .battery:
            OmitSmallCard(title: OmitLang.get("BATTERY", lang: language), value: monitor.batteryPercentString, icon: monitor.batteryIcon, color: monitor.batteryColor)
        case .network:
            OmitSmallCard(title: OmitLang.get("DOWNLOAD", lang: language), value: monitor.networkSpeedString, icon: "wifi", color: .orange)
        case .trash:
            OmitSmallCard(title: OmitLang.get("TRASH_BIN", lang: language), value: monitor.trashSizeString, icon: "trash", color: .pink)
                .contentShape(Rectangle())
                .onTapGesture { monitor.emptyTrashAction() }
        }
    }
}

// --- 权限引导卡片 [新增] ---
// --- 权限引导卡片 (幽灵态 + 微光交互) ---
struct PermissionGuideView: View {
    let language: Language
    @State private var isHovering = false // [新增] 记录鼠标悬停状态
    
    var body: some View {
        VStack(spacing: 24) {
            
            // 1. 图标
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 54))
                .foregroundStyle(.primary.opacity(0.4))
            
            // 2. 文字组
            VStack(spacing: 8) {
                Text(OmitLang.get("PERM_TITLE", lang: language))
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                
                Text(OmitLang.get("PERM_DESC", lang: language))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 30)
            }
            
            // 3. 按钮：微光交互版
            Button(action: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text(OmitLang.get("PERM_BTN", lang: language))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isHovering ? .white : .primary.opacity(0.9)) // 悬停时文字变纯白
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    // [动态背景] 悬停时更亮，平时更淡
                    .background(
                        Material.regular  // <--- 显式指定 Material 类型
                            .opacity(isHovering ? 0.9 : 0.4) // 直接在后面切换透明度，代码更简洁
                    )
                    .clipShape(Capsule())
                    // [动态边框] 悬停时加光晕
                    .overlay(
                        Capsule()
                            .stroke(
                                isHovering ? Color.white.opacity(0.5) : Color.white.opacity(0.1),
                                lineWidth: isHovering ? 1 : 0.5
                            )
                    )
                    // [动态阴影] 悬停时增加发光感
                    .shadow(
                        color: isHovering ? Color.white.opacity(0.2) : Color.black.opacity(0.2),
                        radius: isHovering ? 15 : 10,
                        x: 0,
                        y: isHovering ? 0 : 5
                    )
                    .animation(.easeInOut(duration: 0.2), value: isHovering) // 平滑过渡动画
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering // 监听鼠标进出
            }
            
            // 4. 底部提示
            Text(OmitLang.get("PERM_HINT", lang: language))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// --- 设置页面 (加入开机自启) ---
struct SettingsView: View {
    @ObservedObject var launchManager: LaunchManager // [新增]
    
    @AppStorage("showMemory") private var showMemory = true
    @AppStorage("showStorage") private var showStorage = true
    @AppStorage("showCPU") private var showCPU = true
    @AppStorage("showBattery") private var showBattery = true
    @AppStorage("showNetwork") private var showNetwork = true
    @AppStorage("showTrash") private var showTrash = true
    
    @Binding var languageRaw: String
    var language: Language { Language(rawValue: languageRaw) ?? .chinese }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            Text(OmitLang.get("DISPLAY_MODULES", lang: language))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 0) {
                AlignedToggleRow(title: OmitLang.get("MEMORY", lang: language), icon: "memorychip", isOn: $showMemory)
                AlignedToggleRow(title: OmitLang.get("STORAGE", lang: language), icon: "internaldrive", isOn: $showStorage)
                AlignedToggleRow(title: OmitLang.get("CPU_LOAD", lang: language), icon: "cpu", isOn: $showCPU)
                AlignedToggleRow(title: OmitLang.get("BATTERY", lang: language), icon: "battery.100", isOn: $showBattery)
                AlignedToggleRow(title: OmitLang.get("DOWNLOAD", lang: language), icon: "wifi", isOn: $showNetwork)
                AlignedToggleRow(title: OmitLang.get("TRASH_BIN", lang: language), icon: "trash", isOn: $showTrash)
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            Text(OmitLang.get("PREFERENCES", lang: language))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            
            VStack(spacing: 0) {
                // [新增] 开机自启开关
                HStack {
                    Label(OmitLang.get("LAUNCH_LOGIN", lang: language), systemImage: "bolt.fill")
                        .font(.system(size: 14))
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { launchManager.isLaunchAtLoginEnabled },
                        set: { launchManager.toggleLaunchAtLogin(enabled: $0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(12)
                
                Divider().background(Color.white.opacity(0.1))
                
                HStack {
                    Label(OmitLang.get("LANGUAGE", lang: language), systemImage: "globe")
                        .font(.system(size: 14))
                    Spacer()
                    Picker("", selection: $languageRaw) {
                        ForEach(Language.allCases) { lang in
                            Text(lang.rawValue).tag(lang.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)
                }
                .padding(12)
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text(OmitLang.get("QUIT", lang: language))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.bottom, 10)
    }
}

struct AlignedToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 14))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .primary))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// OmitCard 等组件保持不变，这里省略，请保留原有的卡片组件代码...
// (为了代码完整性，请确保下面的 OmitCard, OmitSmallCard, OmitWideCard 还在文件里)
struct OmitCard: View {
    let title: String
    let value: String
    let subValue: String
    let percent: Double
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.05), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: percent)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color.opacity(0.6))
            }
            .frame(width: 48, height: 48)
            .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .bottom) {
                    Text(title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(color)
                }
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(subValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct OmitSmallCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(color)
                    }
                Spacer()
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .opacity(0.6)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct OmitWideCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(color)
                    }
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Spacer()
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    ContentView().background(Color.black)
}

// --- 这是一个专门制造“高级磨砂感”的组件 ---
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow // 让背景透视
        view.state = .active              // 保持激活状态
        view.material = .hudWindow        // <--- 关键！这是“HUD”材质，最正宗的深色磨砂
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
