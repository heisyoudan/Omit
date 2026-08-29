import AppKit
import Foundation
import SwiftUI

@MainActor
private final class LayoutStressDriver: ObservableObject {
    @Published var showSettings = false
    @Published var showMemory = true
    @Published var showStorage = true
    @Published var showCPU = true
    @Published var showBattery = true
    @Published var showNetwork = true
    @Published var showThermal = true
    @Published var languageRaw = Language.english.rawValue
    @Published var appearanceRaw = AppAppearance.system.rawValue
    @Published var dashboardState = OmitDashboardState.standard

    var visibleModules: Set<OmitModule> {
        DashboardModuleSelection.visibleModules(
            preferences: DashboardModulePreferences(
                showCPU: showCPU,
                showBattery: showBattery,
                showNetwork: showNetwork,
                showThermal: showThermal,
                showTrash: false
            ),
            hasBattery: true,
            capabilities: .appStore
        )
    }
}

@MainActor
private struct LayoutStressView: View {
    @ObservedObject var driver: LayoutStressDriver
    @StateObject private var launchManager = LaunchManager()

    var body: some View {
        OmitPanelContent(
            launchManager: launchManager,
            dashboardState: driver.dashboardState,
            language: Language(rawValue: driver.languageRaw) ?? .english,
            appearance: AppAppearance(rawValue: driver.appearanceRaw) ?? .system,
            capabilities: .appStore,
            visibleModules: driver.visibleModules,
            showMemory: driver.showMemory,
            showStorage: driver.showStorage,
            showSettings: driver.showSettings,
            languageRaw: $driver.languageRaw,
            appearanceRaw: $driver.appearanceRaw,
            onAuthorizeTrash: {},
            onClearTrash: {},
            onSettings: { driver.showSettings.toggle() }
        )
    }
}

@main
struct MenuBarLayoutProbe {
    @MainActor
    static func main() async {
        _ = NSApplication.shared
        let driver = LayoutStressDriver()
        let hostingView = NSHostingView(rootView: LayoutStressView(driver: driver))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 312, height: 520),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFrontRegardless()

        await settle(window)
        let baseline = hostingView.fittingSize

        var iteration = 0
        for cycle in 0 ..< 8 {
            for mask in 0 ..< 16 {
                driver.showSettings = true
                driver.showMemory = (cycle + mask).isMultiple(of: 2)
                driver.showStorage = (cycle + mask).isMultiple(of: 3)
                driver.showCPU = mask & 1 != 0
                driver.showBattery = mask & 2 != 0
                driver.showNetwork = mask & 4 != 0
                driver.showThermal = mask & 8 != 0
                driver.appearanceRaw = AppAppearance.allCases[iteration % AppAppearance.allCases.count].rawValue
                await settle(window)

                driver.showSettings = false
                await settle(window)
                validate(hostingView.fittingSize, iteration: iteration)
                iteration += 1
            }
        }

        driver.showMemory = true
        driver.showStorage = true
        driver.showCPU = true
        driver.showBattery = true
        driver.showNetwork = true
        driver.showThermal = true
        driver.appearanceRaw = AppAppearance.system.rawValue
        await settle(window)
        let restored = hostingView.fittingSize
        expect(abs(restored.width - baseline.width) < 1 && abs(restored.height - baseline.height) < 1, "layout returns to its baseline size")

        for sample in 0 ..< 64 {
            var state = driver.dashboardState
            state.cpuTrend.append(Double((sample * 17) % 100) / 100)
            state.networkDownloadTrend.append(Double((sample * 31) % 240) * 1_000)
            state.networkUploadTrend.append(Double((sample * 11) % 80) * 1_000)
            state.cpuTrend = Array(state.cpuTrend.suffix(30))
            state.networkDownloadTrend = Array(state.networkDownloadTrend.suffix(30))
            state.networkUploadTrend = Array(state.networkUploadTrend.suffix(30))
            driver.dashboardState = state
            await settle(window)
            let updated = hostingView.fittingSize
            expect(abs(updated.width - restored.width) < 1 && abs(updated.height - restored.height) < 1, "trend redraw keeps fixed fitting size at sample \(sample)")
        }

        window.close()
        print("MenuBarLayoutProbe: PASS — 16 module combinations, 128 settings/dashboard cycles, and 64 trend redraws converged")
    }

    @MainActor
    private static func settle(_ window: NSWindow) async {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 5_000_000)
        guard let contentView = window.contentView else { return }
        window.setContentSize(contentView.fittingSize)
        contentView.layoutSubtreeIfNeeded()
    }

    private static func validate(_ size: NSSize, iteration: Int) {
        expect(size.width.isFinite && size.height.isFinite, "finite fitting size at iteration \(iteration)")
        expect(size.width > 0 && size.height > 0 && size.height < 2_000, "bounded fitting size at iteration \(iteration)")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("MenuBarLayoutProbe: FAIL — \(message)\n", stderr)
            exit(1)
        }
    }
}
