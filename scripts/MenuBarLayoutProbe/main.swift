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
    @Published var showTrash = true
    @Published var languageRaw = Language.english.rawValue
    @Published var appearanceRaw = AppAppearance.system.rawValue

    var visibleModules: Set<OmitModule> {
        var result = Set<OmitModule>()
        if showCPU { result.insert(.cpu) }
        if showBattery { result.insert(.battery) }
        if showNetwork { result.insert(.network) }
        if showTrash { result.insert(.trash) }
        return result
    }
}

@MainActor
private struct LayoutStressView: View {
    @ObservedObject var driver: LayoutStressDriver
    @StateObject private var launchManager = LaunchManager()

    var body: some View {
        OmitPanelContent(
            launchManager: launchManager,
            dashboardState: .standard,
            language: Language(rawValue: driver.languageRaw) ?? .english,
            appearance: AppAppearance(rawValue: driver.appearanceRaw) ?? .system,
            visibleModules: driver.visibleModules,
            showMemory: driver.showMemory,
            showStorage: driver.showStorage,
            showSettings: driver.showSettings,
            languageRaw: $driver.languageRaw,
            appearanceRaw: $driver.appearanceRaw,
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

        for iteration in 0 ..< 80 {
            driver.showSettings = true
            driver.showMemory = iteration.isMultiple(of: 2)
            driver.showStorage = iteration.isMultiple(of: 3)
            driver.showCPU = iteration.isMultiple(of: 4)
            driver.showBattery = iteration.isMultiple(of: 5)
            driver.showNetwork = iteration.isMultiple(of: 6)
            driver.showTrash = iteration.isMultiple(of: 7)
            driver.appearanceRaw = AppAppearance.allCases[iteration % AppAppearance.allCases.count].rawValue
            await settle(window)

            driver.showSettings = false
            await settle(window)
            validate(hostingView.fittingSize, iteration: iteration)
        }

        driver.showMemory = true
        driver.showStorage = true
        driver.showCPU = true
        driver.showBattery = true
        driver.showNetwork = true
        driver.showTrash = true
        driver.appearanceRaw = AppAppearance.system.rawValue
        await settle(window)
        let restored = hostingView.fittingSize
        expect(abs(restored.width - baseline.width) < 1 && abs(restored.height - baseline.height) < 1, "layout returns to its baseline size")

        window.close()
        print("MenuBarLayoutProbe: PASS — 80 settings/dashboard cycles and 480 module mutations converged")
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
