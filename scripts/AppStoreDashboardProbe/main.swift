import Foundation

@main
struct AppStoreDashboardProbe {
    static func main() {
        verifyCapabilityMatrix()
        verifyThermalMapping()
        verifyBatteryVisibility()
        verifyBatteryPowerPresentation()
        verifyAllLayoutCombinations()
        print("AppStoreDashboardProbe: PASS — capability, Thermal, battery visibility, and all 16 layouts")
    }

    private static func verifyCapabilityMatrix() {
        let appStore = ProductCapabilities.forVariant(.appStore)
        expect(!appStore.supportsTrash, "App Store capability excludes Trash")
        expect(!appStore.dashboardModules.contains(.trash), "App Store Dashboard excludes Trash")
        expect(!appStore.settingsModules.contains(.trash), "App Store Settings excludes Trash")
        expect(appStore.dashboardModules == [.cpu, .battery, .network, .thermal], "App Store status capabilities are explicit")

        #if OMIT_APP_STORE
        expect(ProductCapabilities.current == .appStore, "OMIT_APP_STORE selects App Store capabilities")
        #else
        expect(ProductCapabilities.current == .direct, "Direct compilation selects Direct capabilities")
        #endif

        let direct = ProductCapabilities.forVariant(.direct)
        expect(direct.supportsTrash, "Direct capability retains Trash")
        expect(direct.dashboardModules.contains(.trash) && direct.settingsModules.contains(.trash), "Direct surfaces can express Trash")
    }

    private static func verifyThermalMapping() {
        expect(ThermalState.map(.nominal) == .nominal, "nominal Thermal mapping")
        expect(ThermalState.map(.fair) == .fair, "fair Thermal mapping")
        expect(ThermalState.map(.serious) == .serious, "serious Thermal mapping")
        expect(ThermalState.map(.critical) == .critical, "critical Thermal mapping")
        expect(Set(ThermalState.allCases) == [.nominal, .fair, .serious, .critical, .unavailable], "all typed Thermal fixtures exist")
    }

    private static func verifyBatteryVisibility() {
        let preferences = DashboardModulePreferences(showCPU: false, showBattery: true, showNetwork: false, showThermal: false, showTrash: false)
        let unavailableVisible = DashboardModuleSelection.visibleModules(preferences: preferences, hasBattery: true, capabilities: .appStore)
        expect(unavailableVisible == [.battery], "temporarily unavailable battery remains visible")
        let noBatteryHidden = DashboardModuleSelection.visibleModules(preferences: preferences, hasBattery: false, capabilities: .appStore)
        expect(noBatteryHidden.isEmpty, "explicit noBattery hides Battery")
    }

    private static func verifyBatteryPowerPresentation() {
        expect(BatteryPowerState.resolve(percent: 100, isCharging: false, providingSource: .battery) == .onBattery, "100% on battery is not reported as fully charged")
        expect(BatteryPowerState.resolve(percent: 100, isCharging: false, providingSource: .externalPower) == .fullyCharged, "100% on global AC power is fully charged")
        expect(BatteryPowerState.resolve(percent: 72, isCharging: true, providingSource: .externalPower) == .charging, "active charging on global AC power is reported as charging")
        expect(BatteryPowerState.resolve(percent: 72, isCharging: false, providingSource: .externalPower) == .externalPower, "global AC power overrides a battery description that reports not charging")
        expect(BatteryPowerState.resolve(percent: 72, isCharging: false, providingSource: .unknown) == .onBattery, "unknown global source fails closed")
    }

    private static func verifyAllLayoutCombinations() {
        let modules = StatusCardLayoutPlanner.statusOrder
        for mask in 0 ..< 16 {
            let visible = Set(modules.enumerated().compactMap { index, module in
                mask & (1 << index) == 0 ? nil : module
            })
            let rows = StatusCardLayoutPlanner.rows(for: visible)
            let flattened = rows.flatMap(\.modules)
            expect(Set(flattened) == visible && flattened.count == visible.count, "layout covers combination \(mask) exactly once")
            expect(Set(rows.map(\.id)).count == rows.count, "layout rows have stable unique identity for combination \(mask)")

            switch visible.count {
            case 0: expect(rows.isEmpty, "0 cards -> none")
            case 1: expect(rows.map(\.style) == [.wide], "1 card -> 1 wide")
            case 2: expect(rows.map(\.style) == [.pair], "2 cards -> pair")
            case 3:
                expect(rows.map(\.style) == [.wide, .pair], "3 cards -> wide above pair")
                let contractWidePriority: [OmitModule] = [.network, .thermal, .battery, .cpu]
                let expectedWide = contractWidePriority.first(where: visible.contains)
                expect(rows.first?.modules.first == expectedWide, "3-card wide priority")
            case 4: expect(rows.map(\.style) == [.pair, .pair], "4 cards -> 2+2")
            default: fail("unexpected card count")
            }
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        fputs("AppStoreDashboardProbe: FAIL — \(message)\n", stderr)
        exit(1)
    }
}
