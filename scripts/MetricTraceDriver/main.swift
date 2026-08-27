#if DEBUG
import AppKit
import Foundation

@main
struct MetricTraceDriver {
    static func main() async {
        do {
            let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
            let sink = try options.outputPath.map {
                try DebugMetricTraceSink.file(at: URL(fileURLWithPath: $0))
            } ?? .standardOutput()

            await emitDeterministicFixtures(to: sink)
            guard !options.fixturesOnly else { return }

            _ = NSApplication.shared
            let sampler = SystemMetricSampler(capabilities: .appStore)
            await sampler.configureDebugTrace(sink, generation: 1)
            await sampler.emitDebugLifecycleMarker("driverStart")
            await sampler.resetBaselines()

            let center = NSWorkspace.shared.notificationCenter
            let sleepObserver = center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { await sampler.emitDebugLifecycleMarker("willSleep") }
            }
            let wakeObserver = center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task {
                    await sampler.emitDebugLifecycleMarker("didWake")
                    await sampler.resetBaselines()
                }
            }
            defer {
                center.removeObserver(sleepObserver)
                center.removeObserver(wakeObserver)
            }

            var planner = MonitorSchedulePlanner(cadence: .production)
            let start = ProcessInfo.processInfo.systemUptime
            while ProcessInfo.processInfo.systemUptime - start < options.duration {
                let now = ProcessInfo.processInfo.systemUptime
                for group in planner.dueGroups(at: now) where group != .trash {
                    _ = await sampler.sample(group)
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            await sampler.emitDebugLifecycleMarker("driverEnd")
        } catch {
            fputs("MetricTraceDriver: \(error)\n", stderr)
            exit(2)
        }
    }

    private struct Options {
        let duration: TimeInterval
        let outputPath: String?
        let fixturesOnly: Bool

        init(arguments: [String]) throws {
            var duration: TimeInterval = 600
            var outputPath: String?
            var fixturesOnly = false
            var index = 0
            while index < arguments.count {
                switch arguments[index] {
                case "--duration":
                    index += 1
                    guard index < arguments.count, let value = TimeInterval(arguments[index]), value >= 0 else {
                        throw DriverError.invalidArguments
                    }
                    duration = value
                case "--output":
                    index += 1
                    guard index < arguments.count else { throw DriverError.invalidArguments }
                    outputPath = arguments[index]
                case "--fixtures-only":
                    fixturesOnly = true
                default:
                    throw DriverError.invalidArguments
                }
                index += 1
            }
            self.duration = duration
            self.outputPath = outputPath
            self.fixturesOnly = fixturesOnly
        }
    }

    private enum DriverError: Error {
        case invalidArguments
    }

    private static func emitDeterministicFixtures(to sink: DebugMetricTraceSink) async {
        var sequence: UInt64 = 0
        func next() -> UInt64 {
            sequence &+= 1
            return sequence
        }

        var cpu = CPUUsageCalculator()
        let cpuBaseline = [CPUTicks(user: 100, system: 40, nice: 10, idle: 850)]
        let cpuValid = [CPUTicks(user: 130, system: 50, nice: 10, idle: 910)]
        let cpuRollback = [CPUTicks(user: 2, system: 2, nice: 0, idle: 2)]
        _ = cpu.sample(cpuBaseline)
        let validCPUFraction = cpu.sample(cpuValid)
        let rollbackCPUFraction = cpu.sample(cpuRollback)
        await sink.emit(DebugMetricTraceRecord(
            event: "fixture", sequence: next(), group: "fast", fixtureName: "cpuBaseline",
            cpu: DebugCPUTrace(
                ticks: cpuBaseline.map { debugTicks($0) }, calculatedFraction: nil,
                availability: "unavailable", error: nil
            )
        ))
        await sink.emit(DebugMetricTraceRecord(
            event: "fixture", sequence: next(), group: "fast", fixtureName: "cpuValidDelta",
            cpu: DebugCPUTrace(
                ticks: cpuValid.map { debugTicks($0) }, calculatedFraction: validCPUFraction,
                availability: validCPUFraction == nil ? "unavailable" : "available", error: nil
            )
        ))
        await sink.emit(DebugMetricTraceRecord(
            event: "fixture", sequence: next(), group: "fast", fixtureName: "cpuCounterRollback",
            cpu: DebugCPUTrace(
                ticks: cpuRollback.map { debugTicks($0) }, calculatedFraction: rollbackCPUFraction,
                availability: "unavailable", error: nil
            )
        ))
        var emptyCPU = CPUUsageCalculator()
        let emptyCPUFraction = emptyCPU.sample([])
        await sink.emit(DebugMetricTraceRecord(
            event: "fixture", sequence: next(), group: "fast", fixtureName: "cpuInvalidSnapshot",
            cpu: DebugCPUTrace(ticks: [], calculatedFraction: emptyCPUFraction, availability: "unavailable", error: "emptySnapshot")
        ))

        let memoryCounters = MemoryCounters(
            active: 40, inactive: 30, speculative: 5, wired: 15,
            compressed: 20, purgeable: 8, external: 7, total: 128
        )
        let memory = MemoryUsageCalculator.calculate(memoryCounters)
        await sink.emit(DebugMetricTraceRecord(
            event: "fixture", sequence: next(), group: "memory", fixtureName: "vmDeterministic",
            memory: DebugMemoryTrace(
                activePages: 40, inactivePages: 30, speculativePages: 5, wiredPages: 15,
                compressedPages: 20, purgeablePages: 8, externalPages: 7,
                pageSize: 1, physicalMemory: 128,
                calculatedUsedBytes: memory.used, calculatedActiveBytes: memory.active,
                calculatedFraction: memory.fractionUsed, error: nil
            )
        ))

        var network = NetworkRateCalculator()
        let first = NetworkCounterSample(interfaceName: "en0", receivedBytes: 1_000, transmittedBytes: 2_000, uptime: 1)
        let valid = NetworkCounterSample(interfaceName: "en0", receivedBytes: 3_000, transmittedBytes: 3_000, uptime: 3)
        let switched = NetworkCounterSample(interfaceName: "utun0", receivedBytes: 100, transmittedBytes: 200, uptime: 4)
        let reset = NetworkCounterSample(interfaceName: "utun0", receivedBytes: 10, transmittedBytes: 20, uptime: 5)
        let sleepGap = NetworkCounterSample(interfaceName: "utun0", receivedBytes: 100, transmittedBytes: 200, uptime: 30)
        let networkFixtures: [(String, NetworkCounterSample?, String?)] = [
            ("networkFirstSample", first, "firstSample"),
            ("networkValidDelta", valid, nil),
            ("networkInterfaceSwitch", switched, "interfaceSwitch"),
            ("networkCounterReset", reset, "counterReset"),
            ("networkSleepGap", sleepGap, "sleepGap"),
            ("networkDisconnect", nil, "disconnect")
        ]
        for (name, sample, reason) in networkFixtures {
            let rates = network.sample(sample)
            await sink.emit(DebugMetricTraceRecord(
                event: "fixture", sequence: next(), group: "fast", fixtureName: name,
                network: DebugNetworkTrace(
                    interfaceName: sample?.interfaceName,
                    receivedBytes: sample?.receivedBytes,
                    transmittedBytes: sample?.transmittedBytes,
                    counterUptime: sample?.uptime,
                    calculatedDownloadBytesPerSecond: rates?.downloadBytesPerSecond,
                    calculatedUploadBytesPerSecond: rates?.uploadBytesPerSecond,
                    baselineResetReason: reason
                )
            ))
        }

        let batteryFixtures: [(String, Int?, Int?, Bool?, BatteryProvidingSource?, String)] = [
            ("batteryNoBattery", nil, nil, nil, nil, "noBattery"),
            ("batteryUnavailable", nil, nil, nil, .unknown, "unavailable"),
            ("batteryOnBattery100", 100, 100, false, .battery, BatteryPowerState.onBattery.rawValue),
            ("batteryCharging", 72, 100, true, .externalPower, BatteryPowerState.charging.rawValue),
            ("batteryPowerAdapter", 72, 100, false, .externalPower, BatteryPowerState.externalPower.rawValue),
            ("batteryFullyCharged", 100, 100, false, .externalPower, BatteryPowerState.fullyCharged.rawValue)
        ]
        for (name, current, maximum, charging, source, mapped) in batteryFixtures {
            await sink.emit(DebugMetricTraceRecord(
                event: "fixture", sequence: next(), group: "slow", fixtureName: name,
                battery: DebugBatteryTrace(
                    batteryPresent: name != "batteryNoBattery",
                    providingPowerSourceType: source?.rawValue,
                    currentCapacity: current, maxCapacity: maximum,
                    isCharging: charging, mappedState: mapped
                )
            ))
        }

        let thermalFixtures: [(String, ThermalState)] = [
            ("nominal", .nominal), ("fair", .fair), ("serious", .serious),
            ("critical", .critical), ("unknown", .unavailable)
        ]
        for (raw, mapped) in thermalFixtures {
            await sink.emit(DebugMetricTraceRecord(
                event: "fixture", sequence: next(), group: "fast", fixtureName: "thermal-\(raw)",
                thermal: DebugThermalTrace(rawState: raw, mappedState: mapped.rawValue)
            ))
        }
    }

    private static func debugTicks(_ ticks: CPUTicks) -> DebugCPUTicks {
        DebugCPUTicks(user: ticks.user, system: ticks.system, nice: ticks.nice, idle: ticks.idle)
    }
}
#else
@main
struct MetricTraceDriver {
    static func main() {
        fatalError("MetricTraceDriver requires a DEBUG build")
    }
}
#endif
