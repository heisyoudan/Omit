import Foundation

nonisolated enum OmitModule: String, CaseIterable, Hashable, Identifiable, Sendable {
    case cpu
    case battery
    case network
    case thermal
    case trash

    var id: String { rawValue }
}

nonisolated enum ProductVariant: String, CaseIterable, Sendable {
    case appStore
    case direct
}

nonisolated struct ProductCapabilities: Equatable, Sendable {
    let variant: ProductVariant
    let dashboardModules: Set<OmitModule>
    let settingsModules: Set<OmitModule>

    var supportsTrash: Bool {
        dashboardModules.contains(.trash) && settingsModules.contains(.trash)
    }

    static let appStore = ProductCapabilities(
        variant: .appStore,
        dashboardModules: [.cpu, .battery, .network, .thermal],
        settingsModules: [.cpu, .battery, .network, .thermal]
    )

    static let direct = ProductCapabilities(
        variant: .direct,
        dashboardModules: [.cpu, .battery, .network, .thermal, .trash],
        settingsModules: [.cpu, .battery, .network, .thermal, .trash]
    )

    static func forVariant(_ variant: ProductVariant) -> ProductCapabilities {
        switch variant {
        case .appStore: .appStore
        case .direct: .direct
        }
    }

    static var current: ProductCapabilities {
        #if OMIT_APP_STORE
        .appStore
        #else
        .direct
        #endif
    }
}

nonisolated enum ThermalState: String, CaseIterable, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical
    case unavailable

    static func map(_ state: ProcessInfo.ThermalState) -> ThermalState {
        switch state {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .unavailable
        }
    }
}

nonisolated enum BatteryPowerState: String, Equatable, Sendable {
    case onBattery
    case charging
    case fullyCharged
    case externalPower

    static func resolve(
        percent: Int,
        isCharging: Bool,
        providingSource: BatteryProvidingSource
    ) -> BatteryPowerState {
        guard providingSource == .externalPower else { return .onBattery }
        if isCharging { return .charging }
        return percent >= 100 ? .fullyCharged : .externalPower
    }

    var usesExternalPower: Bool {
        self != .onBattery
    }
}

nonisolated enum BatteryProvidingSource: String, Equatable, Sendable {
    case battery
    case externalPower
    case unknown
}

nonisolated struct DashboardModulePreferences: Equatable, Sendable {
    let showCPU: Bool
    let showBattery: Bool
    let showNetwork: Bool
    let showThermal: Bool
    let showTrash: Bool
}

nonisolated enum DashboardModuleSelection {
    static func visibleModules(
        preferences: DashboardModulePreferences,
        hasBattery: Bool,
        capabilities: ProductCapabilities
    ) -> Set<OmitModule> {
        var modules = Set<OmitModule>()
        if preferences.showCPU { modules.insert(.cpu) }
        if preferences.showBattery && hasBattery { modules.insert(.battery) }
        if preferences.showNetwork { modules.insert(.network) }
        if preferences.showThermal { modules.insert(.thermal) }
        if preferences.showTrash { modules.insert(.trash) }
        return modules.intersection(capabilities.dashboardModules)
    }
}

nonisolated struct StatusCardRow: Equatable, Identifiable, Sendable {
    enum Style: String, Equatable, Sendable {
        case wide
        case pair
    }

    let style: Style
    let modules: [OmitModule]

    var id: String {
        style.rawValue + ":" + modules.map(\.rawValue).joined(separator: ",")
    }
}

nonisolated enum StatusCardLayoutPlanner {
    static let statusOrder: [OmitModule] = [.cpu, .battery, .network, .thermal]
    static let widePriority: [OmitModule] = [.network, .thermal, .battery, .cpu]

    static func rows(for visibleModules: Set<OmitModule>) -> [StatusCardRow] {
        let modules = statusOrder.filter(visibleModules.contains)
        switch modules.count {
        case 0:
            return []
        case 1:
            return [StatusCardRow(style: .wide, modules: modules)]
        case 2:
            return [StatusCardRow(style: .pair, modules: modules)]
        case 3:
            guard let wide = widePriority.first(where: visibleModules.contains) else { return [] }
            return [
                StatusCardRow(style: .wide, modules: [wide]),
                StatusCardRow(style: .pair, modules: modules.filter { $0 != wide })
            ]
        default:
            return [
                StatusCardRow(style: .pair, modules: Array(modules.prefix(2))),
                StatusCardRow(style: .pair, modules: Array(modules.suffix(2)))
            ]
        }
    }
}
