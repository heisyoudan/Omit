import Darwin
import Foundation
import IOKit.ps

nonisolated enum CPUState: Equatable, Sendable { case unavailable, available(String) }
nonisolated enum BatteryState: Equatable, Sendable { case noBattery, unavailable, available(value: String, powerState: BatteryPowerState) }
nonisolated enum NetworkState: Equatable, Sendable { case unavailable, available(download: String, upload: String) }
nonisolated enum MetricKind: Hashable, Sendable { case cpu, memory, network, thermal, battery, storage, trash }
nonisolated enum MetricSamplingError: Error, Equatable, Sendable {
    case kernel(metric: MetricKind, code: Int32)
    case storage(String)
    case invalidStorageCapacity
}

nonisolated struct MemoryProjection: Sendable { let used, total, active: String; let fractionUsed: Double }
nonisolated struct StorageProjection: Sendable { let available: String; let fractionUsed: Double }
nonisolated struct FastProjection: Sendable {
    let cpu: CPUState
    let network: NetworkState
    let thermal: ThermalState
    let failures: [MetricKind: MetricSamplingError]
}
nonisolated struct SlowProjection: Sendable {
    let battery: BatteryState; let storage: StorageProjection?; let failures: [MetricKind: MetricSamplingError]
}
nonisolated enum MonitorProjection: Sendable {
    case fast(FastProjection)
    case memory(Result<MemoryProjection, MetricSamplingError>)
    case slow(SlowProjection)
    case trash(TrashState)
}

actor SystemMetricSampler {
    private let capabilities: ProductCapabilities
    private let networkSampler: NetworkCounterSampler
    private let trashAccessService: TrashAccessService
    private let byteFormatter: ByteCountFormatter
    private var cpuCalculator = CPUUsageCalculator()
    private var networkCalculator = NetworkRateCalculator()

    #if DEBUG
    private var debugTraceSink = DebugMetricTraceSink.fromEnvironment()
    private var debugSequence: UInt64 = 0
    private var debugInFlightCount = 0
    private var debugGeneration: UInt64 = 0
    private var debugCPUTrace: DebugCPUTrace?
    private var debugMemoryTrace: DebugMemoryTrace?
    private var debugStorageTrace: DebugStorageTrace?
    private var debugNetworkTrace: DebugNetworkTrace?
    private var debugBatteryTrace: DebugBatteryTrace?
    private var debugThermalTrace: DebugThermalTrace?
    #endif

    init(
        capabilities: ProductCapabilities = .current,
        trashAccessService: TrashAccessService = TrashAccessService()
    ) {
        self.capabilities = capabilities
        self.networkSampler = NetworkCounterSampler()
        self.trashAccessService = trashAccessService
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        byteFormatter = formatter
    }

    func resetBaselines() async {
        cpuCalculator = CPUUsageCalculator()
        networkCalculator = NetworkRateCalculator()
        #if DEBUG
        await emitDebugLifecycleMarker("reset")
        #endif
    }

    func sampleBatteryState() async -> BatteryState {
        #if DEBUG
        let debugContext = beginDebugSample(groupName: "batteryEvent")
        #endif
        let state = sampleBattery()
        #if DEBUG
        await finishDebugSample(debugContext)
        #endif
        return state
    }

    #if DEBUG
    func configureDebugTrace(_ sink: DebugMetricTraceSink?, generation: UInt64 = 0) {
        debugTraceSink = sink
        debugGeneration = generation
    }

    func updateDebugGeneration(_ generation: UInt64) {
        debugGeneration = generation
    }

    func emitDebugLifecycleMarker(_ marker: String) async {
        guard let debugTraceSink else { return }
        debugSequence &+= 1
        let now = ProcessInfo.processInfo.systemUptime
        await debugTraceSink.emit(DebugMetricTraceRecord(
            event: "lifecycle",
            marker: marker,
            sequence: debugSequence,
            startUptime: now,
            endUptime: now,
            inFlightCount: debugInFlightCount,
            generation: debugGeneration
        ))
    }
    #endif

    func sample(_ group: MonitorGroup) async -> MonitorProjection {
        #if DEBUG
        let debugContext = beginDebugSample(groupName: debugGroupName(group))
        #endif
        let projection: MonitorProjection = switch group {
        case .fast: .fast(sampleFast())
        case .memory: .memory(sampleMemory())
        case .slow: .slow(sampleSlow())
        case .trash:
            .trash(capabilities.supportsTrash ? await trashAccessService.scan() : .unauthorized)
        }
        #if DEBUG
        await finishDebugSample(debugContext)
        #endif
        return projection
    }

    func authorizeTrash(at selectedURL: URL) async -> TrashState {
        guard capabilities.supportsTrash else { return .unauthorized }
        return await trashAccessService.authorize(selectedURL: selectedURL)
    }

    func trashAuthorizationCancelled() async -> TrashState {
        guard capabilities.supportsTrash else { return .unauthorized }
        return await trashAccessService.authorizationCancelled()
    }

    func clearTrash() async -> TrashClearReport {
        guard capabilities.supportsTrash else {
            return TrashClearReport(
                deletedItemNames: [],
                failures: [TrashItemFailure(itemName: "Trash", message: "Unavailable in this product variant")]
            )
        }
        return await trashAccessService.clear()
    }

    private func sampleFast() -> FastProjection {
        var failures: [MetricKind: MetricSamplingError] = [:]
        let cpu: CPUState
        switch sampleCPU() {
        case .success(let state): cpu = state
        case .failure(let error): cpu = .unavailable; failures[.cpu] = error
        }

        let network: NetworkState
        let networkCounter = networkSampler.sample(uptime: ProcessInfo.processInfo.systemUptime)
        #if DEBUG
        let networkResetReason = debugNetworkResetReason(previous: networkCalculator.previous, current: networkCounter)
        #endif
        let networkRates = networkCalculator.sample(networkCounter)
        if let rates = networkRates {
            network = .available(download: formatRate(rates.downloadBytesPerSecond), upload: formatRate(rates.uploadBytesPerSecond))
        } else {
            network = .unavailable
        }
        let rawThermalState = ProcessInfo.processInfo.thermalState
        let mappedThermalState = ThermalState.map(rawThermalState)
        #if DEBUG
        debugNetworkTrace = DebugNetworkTrace(
            interfaceName: networkCounter?.interfaceName,
            receivedBytes: networkCounter?.receivedBytes,
            transmittedBytes: networkCounter?.transmittedBytes,
            counterUptime: networkCounter?.uptime,
            calculatedDownloadBytesPerSecond: networkRates?.downloadBytesPerSecond,
            calculatedUploadBytesPerSecond: networkRates?.uploadBytesPerSecond,
            baselineResetReason: networkResetReason
        )
        debugThermalTrace = DebugThermalTrace(
            rawState: debugThermalName(rawThermalState),
            mappedState: mappedThermalState.rawValue
        )
        #endif
        return FastProjection(
            cpu: cpu,
            network: network,
            thermal: mappedThermalState,
            failures: failures
        )
    }

    private func sampleMemory() -> Result<MemoryProjection, MetricSamplingError> {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else {
            #if DEBUG
            debugMemoryTrace = DebugMemoryTrace(
                activePages: UInt64(stats.active_count), inactivePages: UInt64(stats.inactive_count),
                speculativePages: UInt64(stats.speculative_count), wiredPages: UInt64(stats.wire_count),
                compressedPages: UInt64(stats.compressor_page_count), purgeablePages: UInt64(stats.purgeable_count),
                externalPages: UInt64(stats.external_page_count), pageSize: UInt64(getpagesize()),
                physicalMemory: ProcessInfo.processInfo.physicalMemory,
                calculatedUsedBytes: nil, calculatedActiveBytes: nil, calculatedFraction: nil,
                error: String(describing: MetricSamplingError.kernel(metric: .memory, code: result))
            )
            #endif
            return .failure(.kernel(metric: .memory, code: result))
        }

        let pageSize = UInt64(getpagesize())
        let counters = MemoryCounters(
            active: bytes(stats.active_count, pageSize: pageSize), inactive: bytes(stats.inactive_count, pageSize: pageSize),
            speculative: bytes(stats.speculative_count, pageSize: pageSize), wired: bytes(stats.wire_count, pageSize: pageSize),
            compressed: bytes(stats.compressor_page_count, pageSize: pageSize), purgeable: bytes(stats.purgeable_count, pageSize: pageSize),
            external: bytes(stats.external_page_count, pageSize: pageSize), total: ProcessInfo.processInfo.physicalMemory
        )
        let usage = MemoryUsageCalculator.calculate(counters)
        #if DEBUG
        debugMemoryTrace = DebugMemoryTrace(
            activePages: UInt64(stats.active_count), inactivePages: UInt64(stats.inactive_count),
            speculativePages: UInt64(stats.speculative_count), wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count), purgeablePages: UInt64(stats.purgeable_count),
            externalPages: UInt64(stats.external_page_count), pageSize: pageSize,
            physicalMemory: counters.total,
            calculatedUsedBytes: usage.used, calculatedActiveBytes: usage.active,
            calculatedFraction: usage.fractionUsed, error: nil
        )
        #endif
        return .success(MemoryProjection(
            used: byteFormatter.string(fromByteCount: Int64(usage.used)), total: byteFormatter.string(fromByteCount: Int64(usage.total)),
            active: byteFormatter.string(fromByteCount: Int64(usage.active)), fractionUsed: usage.fractionUsed
        ))
    }

    private func sampleCPU() -> Result<CPUState, MetricSamplingError> {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var count: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &count)
        guard result == KERN_SUCCESS, let cpuInfo, numCPUs > 0, count >= numCPUs * natural_t(CPU_STATE_MAX) else {
            #if DEBUG
            debugCPUTrace = DebugCPUTrace(
                ticks: [], calculatedFraction: nil, availability: "unavailable",
                error: String(describing: MetricSamplingError.kernel(metric: .cpu, code: result))
            )
            #endif
            return .failure(.kernel(metric: .cpu, code: result))
        }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(Int(count) * MemoryLayout<integer_t>.stride))
        }
        let ticks = (0 ..< Int(numCPUs)).map { cpu in
            let offset = cpu * Int(CPU_STATE_MAX)
            return CPUTicks(
                user: unsignedTick(cpuInfo[offset + Int(CPU_STATE_USER)]), system: unsignedTick(cpuInfo[offset + Int(CPU_STATE_SYSTEM)]),
                nice: unsignedTick(cpuInfo[offset + Int(CPU_STATE_NICE)]), idle: unsignedTick(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            )
        }
        guard let usage = cpuCalculator.sample(ticks) else {
            #if DEBUG
            debugCPUTrace = DebugCPUTrace(
                ticks: ticks.map { DebugCPUTicks(user: $0.user, system: $0.system, nice: $0.nice, idle: $0.idle) }, calculatedFraction: nil,
                availability: "unavailable", error: nil
            )
            #endif
            return .success(.unavailable)
        }
        #if DEBUG
        debugCPUTrace = DebugCPUTrace(
            ticks: ticks.map { DebugCPUTicks(user: $0.user, system: $0.system, nice: $0.nice, idle: $0.idle) }, calculatedFraction: usage,
            availability: "available", error: nil
        )
        #endif
        return .success(.available(String(format: "%.0f%%", usage * 100)))
    }

    private func sampleSlow() -> SlowProjection {
        var failures: [MetricKind: MetricSamplingError] = [:]
        let storage: StorageProjection?
        switch sampleStorage() {
        case .success(let value): storage = value
        case .failure(let error): storage = nil; failures[.storage] = error
        }
        return SlowProjection(battery: sampleBattery(), storage: storage, failures: failures)
    }

    private func sampleStorage() -> Result<StorageProjection, MetricSamplingError> {
        do {
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [
                .volumeIdentifierKey,
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityForOpportunisticUsageKey
            ])
            guard let capacity = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity,
                  capacity > 0, available >= 0, available <= capacity else {
                #if DEBUG
                debugStorageTrace = DebugStorageTrace(
                    volumeIdentifier: values.volumeIdentifier.map { String(describing: $0) },
                    totalCapacity: values.volumeTotalCapacity.map(Int64.init),
                    availableCapacity: values.volumeAvailableCapacity.map(Int64.init),
                    importantUsageCapacity: values.volumeAvailableCapacityForImportantUsage,
                    opportunisticUsageCapacity: values.volumeAvailableCapacityForOpportunisticUsage,
                    calculatedFraction: nil,
                    error: String(describing: MetricSamplingError.invalidStorageCapacity)
                )
                #endif
                return .failure(.invalidStorageCapacity)
            }
            let fractionUsed = min(max(Double(capacity - available) / Double(capacity), 0), 1)
            #if DEBUG
            debugStorageTrace = DebugStorageTrace(
                volumeIdentifier: values.volumeIdentifier.map { String(describing: $0) },
                totalCapacity: Int64(capacity), availableCapacity: Int64(available),
                importantUsageCapacity: values.volumeAvailableCapacityForImportantUsage,
                opportunisticUsageCapacity: values.volumeAvailableCapacityForOpportunisticUsage,
                calculatedFraction: fractionUsed, error: nil
            )
            #endif
            return .success(StorageProjection(
                available: byteFormatter.string(fromByteCount: Int64(available)),
                fractionUsed: fractionUsed
            ))
        } catch {
            #if DEBUG
            debugStorageTrace = DebugStorageTrace(
                volumeIdentifier: nil, totalCapacity: nil, availableCapacity: nil,
                importantUsageCapacity: nil, opportunisticUsageCapacity: nil,
                calculatedFraction: nil, error: String(describing: error)
            )
            #endif
            return .failure(.storage(String(describing: error)))
        }
    }

    private func sampleBattery() -> BatteryState {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        let internalBattery = sources.first { source in
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { return false }
            return description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
        guard let internalBattery else {
            #if DEBUG
            debugBatteryTrace = DebugBatteryTrace(
                batteryPresent: false, providingPowerSourceType: nil,
                currentCapacity: nil, maxCapacity: nil, isCharging: nil,
                mappedState: "noBattery"
            )
            #endif
            return .noBattery
        }
        guard let info = IOPSGetPowerSourceDescription(snapshot, internalBattery)?.takeUnretainedValue() as? [String: Any],
              let capacity = info[kIOPSCurrentCapacityKey] as? Int, let maxCapacity = info[kIOPSMaxCapacityKey] as? Int,
              maxCapacity > 0 else {
            #if DEBUG
            debugBatteryTrace = DebugBatteryTrace(
                batteryPresent: true,
                providingPowerSourceType: IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?,
                currentCapacity: nil, maxCapacity: nil, isCharging: nil,
                mappedState: "unavailable"
            )
            #endif
            return .unavailable
        }
        let percent = min(max(Int((Double(capacity) / Double(maxCapacity)) * 100), 0), 100)
        let isCharging = (info[kIOPSIsChargingKey] as? Bool) == true
        let providingSourceType = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
        let providingSource: BatteryProvidingSource
        switch providingSourceType {
        case kIOPSACPowerValue: providingSource = .externalPower
        case kIOPSBatteryPowerValue: providingSource = .battery
        default: providingSource = .unknown
        }
        let powerState = BatteryPowerState.resolve(
            percent: percent,
            isCharging: isCharging,
            providingSource: providingSource
        )
        #if DEBUG
        debugBatteryTrace = DebugBatteryTrace(
            batteryPresent: true, providingPowerSourceType: providingSourceType,
            currentCapacity: capacity, maxCapacity: maxCapacity,
            isCharging: isCharging, mappedState: powerState.rawValue
        )
        #endif
        return .available(value: "\(percent)%", powerState: powerState)
    }

    #if DEBUG
    private struct DebugSampleContext: Sendable {
        let sequence: UInt64
        let groupName: String
        let wallClockUnix: TimeInterval
        let startUptime: TimeInterval
        let inFlightCount: Int
    }

    private func beginDebugSample(groupName: String) -> DebugSampleContext? {
        guard debugTraceSink != nil else { return nil }
        debugSequence &+= 1
        debugInFlightCount += 1
        debugCPUTrace = nil
        debugMemoryTrace = nil
        debugStorageTrace = nil
        debugNetworkTrace = nil
        debugBatteryTrace = nil
        debugThermalTrace = nil
        return DebugSampleContext(
            sequence: debugSequence,
            groupName: groupName,
            wallClockUnix: Date().timeIntervalSince1970,
            startUptime: ProcessInfo.processInfo.systemUptime,
            inFlightCount: debugInFlightCount
        )
    }

    private func finishDebugSample(_ context: DebugSampleContext?) async {
        guard let context else { return }
        debugInFlightCount = max(debugInFlightCount - 1, 0)
        guard let debugTraceSink else { return }
        let payloads: (
            cpu: DebugCPUTrace?, memory: DebugMemoryTrace?, storage: DebugStorageTrace?,
            network: DebugNetworkTrace?, battery: DebugBatteryTrace?, thermal: DebugThermalTrace?
        ) = switch context.groupName {
        case "fast": (debugCPUTrace, nil, nil, debugNetworkTrace, nil, debugThermalTrace)
        case "memory": (nil, debugMemoryTrace, nil, nil, nil, nil)
        case "slow": (nil, nil, debugStorageTrace, nil, debugBatteryTrace, nil)
        case "batteryEvent": (nil, nil, nil, nil, debugBatteryTrace, nil)
        default: (nil, nil, nil, nil, nil, nil)
        }
        await debugTraceSink.emit(DebugMetricTraceRecord(
            event: "sample",
            sequence: context.sequence,
            group: context.groupName,
            wallClockUnix: context.wallClockUnix,
            startUptime: context.startUptime,
            endUptime: ProcessInfo.processInfo.systemUptime,
            inFlightCount: context.inFlightCount,
            generation: debugGeneration,
            cpu: payloads.cpu,
            memory: payloads.memory,
            storage: payloads.storage,
            network: payloads.network,
            battery: payloads.battery,
            thermal: payloads.thermal
        ))
    }

    private func debugGroupName(_ group: MonitorGroup) -> String {
        switch group {
        case .fast: "fast"
        case .memory: "memory"
        case .slow: "slow"
        case .trash: "trash"
        }
    }

    private func debugNetworkResetReason(
        previous: NetworkCounterSample?,
        current: NetworkCounterSample?
    ) -> String? {
        guard let current else { return "disconnect" }
        guard let previous else { return "firstSample" }
        guard previous.interfaceName == current.interfaceName else { return "interfaceSwitch" }
        guard current.receivedBytes >= previous.receivedBytes,
              current.transmittedBytes >= previous.transmittedBytes else { return "counterReset" }
        let interval = current.uptime - previous.uptime
        guard interval > 0 else { return "invalidInterval" }
        guard interval <= networkCalculator.maximumInterval else { return "sleepGap" }
        return nil
    }

    private func debugThermalName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "nominal"
        case .fair: "fair"
        case .serious: "serious"
        case .critical: "critical"
        @unknown default: "unknown"
        }
    }
    #endif

    private func bytes(_ pages: natural_t, pageSize: UInt64) -> UInt64 {
        let (value, overflow) = UInt64(pages).multipliedReportingOverflow(by: pageSize)
        return overflow ? .max : value
    }
    private func unsignedTick(_ value: integer_t) -> UInt64 { UInt64(UInt32(bitPattern: value)) }
    private func formatRate(_ rate: Double) -> String {
        byteFormatter.string(fromByteCount: Int64(min(max(rate, 0), Double(Int64.max)).rounded())) + "/s"
    }
}
