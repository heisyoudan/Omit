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

    func resetBaselines() {
        cpuCalculator = CPUUsageCalculator()
        networkCalculator = NetworkRateCalculator()
    }

    func sample(_ group: MonitorGroup) async -> MonitorProjection {
        switch group {
        case .fast: .fast(sampleFast())
        case .memory: .memory(sampleMemory())
        case .slow: .slow(sampleSlow())
        case .trash:
            .trash(capabilities.supportsTrash ? await trashAccessService.scan() : .unauthorized)
        }
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
        if let rates = networkCalculator.sample(networkSampler.sample(uptime: ProcessInfo.processInfo.systemUptime)) {
            network = .available(download: formatRate(rates.downloadBytesPerSecond), upload: formatRate(rates.uploadBytesPerSecond))
        } else {
            network = .unavailable
        }
        return FastProjection(
            cpu: cpu,
            network: network,
            thermal: ThermalState.map(ProcessInfo.processInfo.thermalState),
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
        guard result == KERN_SUCCESS else { return .failure(.kernel(metric: .memory, code: result)) }

        let pageSize = UInt64(getpagesize())
        let usage = MemoryUsageCalculator.calculate(MemoryCounters(
            active: bytes(stats.active_count, pageSize: pageSize), inactive: bytes(stats.inactive_count, pageSize: pageSize),
            speculative: bytes(stats.speculative_count, pageSize: pageSize), wired: bytes(stats.wire_count, pageSize: pageSize),
            compressed: bytes(stats.compressor_page_count, pageSize: pageSize), purgeable: bytes(stats.purgeable_count, pageSize: pageSize),
            external: bytes(stats.external_page_count, pageSize: pageSize), total: ProcessInfo.processInfo.physicalMemory
        ))
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
        guard let usage = cpuCalculator.sample(ticks) else { return .success(.unavailable) }
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
            let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            guard let capacity = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity,
                  capacity > 0, available >= 0, available <= capacity else { return .failure(.invalidStorageCapacity) }
            return .success(StorageProjection(
                available: byteFormatter.string(fromByteCount: Int64(available)),
                fractionUsed: min(max(Double(capacity - available) / Double(capacity), 0), 1)
            ))
        } catch {
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
        guard let internalBattery else { return .noBattery }
        guard let info = IOPSGetPowerSourceDescription(snapshot, internalBattery)?.takeUnretainedValue() as? [String: Any],
              let capacity = info[kIOPSCurrentCapacityKey] as? Int, let maxCapacity = info[kIOPSMaxCapacityKey] as? Int,
              maxCapacity > 0 else { return .unavailable }
        let percent = min(max(Int((Double(capacity) / Double(maxCapacity)) * 100), 0), 100)
        let isCharging = (info[kIOPSIsChargingKey] as? Bool) == true
        let isConnectedToExternalPower = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let powerState = BatteryPowerState.resolve(
            percent: percent,
            isCharging: isCharging,
            isConnectedToExternalPower: isConnectedToExternalPower
        )
        return .available(value: "\(percent)%", powerState: powerState)
    }

    private func bytes(_ pages: natural_t, pageSize: UInt64) -> UInt64 {
        let (value, overflow) = UInt64(pages).multipliedReportingOverflow(by: pageSize)
        return overflow ? .max : value
    }
    private func unsignedTick(_ value: integer_t) -> UInt64 { UInt64(UInt32(bitPattern: value)) }
    private func formatRate(_ rate: Double) -> String {
        byteFormatter.string(fromByteCount: Int64(min(max(rate, 0), Double(Int64.max)).rounded())) + "/s"
    }
}
