#if DEBUG
import Combine
import SwiftUI

@MainActor
final class DebugDashboardDriver: ObservableObject {
    enum BatteryScenario: String, CaseIterable, Identifiable {
        case noBattery, unavailable, onBattery, charging, fullyCharged, externalPower
        var id: String { rawValue }
    }

    enum TrashScenario: String, CaseIterable, Identifiable {
        case unauthorized, empty, content, scanning, error
        var id: String { rawValue }
    }

    @Published var isEnabled = false
    @Published var memoryUsedGB = 13.8
    @Published var memoryTotalGB = 17.2
    @Published var memoryFraction = 0.80
    @Published var storageAvailableGB = 219.8
    @Published var storageFraction = 0.56
    @Published var cpuAvailable = true
    @Published var cpuPercent = 24.0
    @Published var batteryScenario = BatteryScenario.fullyCharged
    @Published var batteryPercent = 100.0
    @Published var networkAvailable = true
    @Published var downloadKB = 3.0
    @Published var uploadKB = 1.0
    @Published var thermalState = ThermalState.nominal
    @Published var trashScenario = TrashScenario.content
    @Published var trashValue = "1.4 GB"

    var hasBattery: Bool { batteryScenario != .noBattery }

    var dashboardState: OmitDashboardState {
        let battery: (String?, BatteryPowerState) = switch batteryScenario {
        case .noBattery, .unavailable: (nil, .onBattery)
        case .onBattery: (percent(batteryPercent), .onBattery)
        case .charging: (percent(batteryPercent), .charging)
        case .fullyCharged: (percent(batteryPercent), .fullyCharged)
        case .externalPower: (percent(batteryPercent), .externalPower)
        }
        let trash: TrashPresentation = switch trashScenario {
        case .unauthorized: .unauthorized
        case .empty: .empty
        case .content: .content(trashValue)
        case .scanning: .scanning
        case .error: .error("Debug scan error")
        }
        return OmitDashboardState(
            memoryUsed: decimalGB(memoryUsedGB),
            memoryTotal: decimalGB(memoryTotalGB),
            memoryPercent: memoryFraction,
            storageAvailable: decimalGB(storageAvailableGB),
            storageUsedPercent: storageFraction,
            cpuValue: cpuAvailable ? percent(cpuPercent) : nil,
            batteryValue: battery.0,
            batteryPowerState: battery.1,
            downloadValue: networkAvailable ? rate(downloadKB) : "—",
            uploadValue: networkAvailable ? rate(uploadKB) : "—",
            thermalState: thermalState,
            trash: trash
        )
    }

    func enable() { isEnabled = true }
    func restore() { isEnabled = false }

    private func percent(_ value: Double) -> String { "\(Int(value.rounded()))%" }
    private func decimalGB(_ value: Double) -> String { String(format: "%.1f GB", value) }
    private func rate(_ value: Double) -> String { String(format: value >= 100 ? "%.0f KB/s" : "%.1f KB/s", value) }
}

struct DebugDashboardPanel: View {
    @ObservedObject var driver: DebugDashboardDriver
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Debug State Driver").font(.headline)
                    Text("Changes project immediately; live sampling continues in the background.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $driver.isEnabled).labelsHidden()
            }

            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    debugSection("Memory") {
                        debugSlider("Used", value: $driver.memoryUsedGB, range: 0...128, suffix: "GB")
                        debugSlider("Total", value: $driver.memoryTotalGB, range: 1...128, suffix: "GB")
                        debugSlider("Ring", value: $driver.memoryFraction, range: 0...1, suffix: "%", multiplier: 100)
                    }
                    debugSection("Storage") {
                        debugSlider("Available", value: $driver.storageAvailableGB, range: 0...2048, suffix: "GB")
                        debugSlider("Used ring", value: $driver.storageFraction, range: 0...1, suffix: "%", multiplier: 100)
                    }
                    debugSection("CPU") {
                        Toggle("Available", isOn: $driver.cpuAvailable)
                        debugSlider("Usage", value: $driver.cpuPercent, range: 0...100, suffix: "%")
                    }
                    debugSection("Battery") {
                        Picker("State", selection: $driver.batteryScenario) {
                            ForEach(DebugDashboardDriver.BatteryScenario.allCases) { Text($0.rawValue).tag($0) }
                        }
                        debugSlider("Capacity", value: $driver.batteryPercent, range: 0...100, suffix: "%")
                    }
                    debugSection("Network") {
                        Toggle("Available", isOn: $driver.networkAvailable)
                        debugSlider("Download", value: $driver.downloadKB, range: 0...1000, suffix: "KB/s")
                        debugSlider("Upload", value: $driver.uploadKB, range: 0...1000, suffix: "KB/s")
                    }
                    debugSection("Thermal") {
                        Picker("State", selection: $driver.thermalState) {
                            ForEach(ThermalState.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                    debugSection("Trash projection (no file access)") {
                        Picker("State", selection: $driver.trashScenario) {
                            ForEach(DebugDashboardDriver.TrashScenario.allCases) { Text($0.rawValue).tag($0) }
                        }
                        TextField("Content value", text: $driver.trashValue)
                    }
                }
            }
            .frame(maxHeight: 510)

            Divider()
            HStack {
                Text(driver.isEnabled ? "Manual projection active" : "Live projection active")
                    .font(.caption).foregroundStyle(driver.isEnabled ? .orange : .secondary)
                Spacer()
                Button("Restore Live", action: onRestore).keyboardShortcut(.cancelAction)
            }
        }
        .padding(16)
        .frame(width: 330)
    }

    private func debugSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
        .padding(10)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func debugSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        suffix: String,
        multiplier: Double = 1
    ) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text("\(Int((value.wrappedValue * multiplier).rounded())) \(suffix)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}
#endif
