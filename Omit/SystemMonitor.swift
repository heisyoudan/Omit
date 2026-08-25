//
//  SystemMonitor.swift
//  Omit
//
//  Created by heisyoudan on 2026/1/16.
//

import Foundation
import Combine
import Darwin
import IOKit.ps

class SystemMonitor: ObservableObject {
    enum CPUState: Equatable {
        case unavailable
        case available(String)
    }

    enum BatteryState: Equatable {
        case noBattery
        case unavailable
        case available(value: String, isCharging: Bool)
    }

    enum NetworkState: Equatable {
        case unavailable
        case available(download: String, upload: String)
    }

    enum TrashState: Equatable {
        case unauthorized
        case empty
        case content(String)
        case scanning
        case error(String)
    }
    
    @Published var memoryUsedString: String = "0 GB"
    @Published var memoryTotalString: String = "16 GB"
    @Published var memoryPercent: Double = 0.0
    @Published var memoryActiveString: String = "0 GB"
    
    @Published var storageFreeString: String = "0 GB"
    @Published var storageUsedPercent: Double = 0.0
    
    @Published private(set) var cpuState: CPUState = .unavailable
    @Published private(set) var batteryState: BatteryState = .unavailable
    @Published private(set) var networkState: NetworkState = .unavailable
    @Published private(set) var trashState: TrashState = .scanning
    
    private var timer: Timer?
    private let fileManager = FileManager.default
    
    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()
    
    private var cpuCalculator = CPUUsageCalculator()
    private var networkCalculator = NetworkRateCalculator()
    private let networkSampler = NetworkCounterSampler()
    
    init() {
        checkPermission() // 启动时先检查一次权限
        startMonitoring()
        updateStats()
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    func checkPermission() {
        let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first!
        do {
            _ = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)
        } catch {
            DispatchQueue.main.async { self.trashState = .unauthorized }
        }
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStats()
        }
    }
    
    @objc func updateStats() {
        updateMemory()
        updateStorage()
        updateCPU()
        updateBattery()
        updateNetwork()
        updateTrash()
    }
    
    private func updateMemory() {
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let hostPort: mach_port_t = mach_host_self()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &size)
            }
        }
        if result == KERN_SUCCESS {
            let pageSize = UInt64(getpagesize())
            let total = ProcessInfo.processInfo.physicalMemory
            let usage = MemoryUsageCalculator.calculate(MemoryCounters(
                active: bytes(stats.active_count, pageSize: pageSize),
                inactive: bytes(stats.inactive_count, pageSize: pageSize),
                speculative: bytes(stats.speculative_count, pageSize: pageSize),
                wired: bytes(stats.wire_count, pageSize: pageSize),
                compressed: bytes(stats.compressor_page_count, pageSize: pageSize),
                purgeable: bytes(stats.purgeable_count, pageSize: pageSize),
                external: bytes(stats.external_page_count, pageSize: pageSize),
                total: total
            ))
            memoryUsedString = byteFormatter.string(fromByteCount: Int64(usage.used))
            memoryTotalString = byteFormatter.string(fromByteCount: Int64(usage.total))
            memoryActiveString = byteFormatter.string(fromByteCount: Int64(usage.active))
            memoryPercent = usage.fractionUsed
        }
    }

    private func bytes(_ pageCount: natural_t, pageSize: UInt64) -> UInt64 {
        let (value, overflow) = UInt64(pageCount).multipliedReportingOverflow(by: pageSize)
        return overflow ? UInt64.max : value
    }
    
    private func updateStorage() {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let capacity = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let used = Int64(capacity - available)
                self.storageFreeString = byteFormatter.string(fromByteCount: Int64(available))
                self.storageUsedPercent = Double(used) / Double(capacity)
            }
        } catch {}
    }
    
    private func updateCPU() {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCpuInfo)
        guard result == KERN_SUCCESS,
              let cpuInfo,
              numCPUs > 0,
              numCpuInfo >= numCPUs * natural_t(CPU_STATE_MAX) else {
            cpuState = .unavailable
            return
        }
        defer {
            let size = Int(numCpuInfo) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(size))
        }

        let ticks = (0 ..< Int(numCPUs)).map { cpu in
            let offset = cpu * Int(CPU_STATE_MAX)
            return CPUTicks(
                user: unsignedTick(cpuInfo[offset + Int(CPU_STATE_USER)]),
                system: unsignedTick(cpuInfo[offset + Int(CPU_STATE_SYSTEM)]),
                nice: unsignedTick(cpuInfo[offset + Int(CPU_STATE_NICE)]),
                idle: unsignedTick(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            )
        }
        if let usage = cpuCalculator.sample(ticks) {
            cpuState = .available(String(format: "%.0f%%", usage * 100))
        } else {
            cpuState = .unavailable
        }
    }

    private func unsignedTick(_ value: integer_t) -> UInt64 {
        UInt64(UInt32(bitPattern: value))
    }
    
    private func updateBattery() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        let internalBattery = sources.first { source in
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                return false
            }
            return description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
        guard let internalBattery else {
            batteryState = .noBattery
            return
        }
        guard let info = IOPSGetPowerSourceDescription(snapshot, internalBattery)?.takeUnretainedValue() as? [String: Any],
              let capacity = info[kIOPSCurrentCapacityKey] as? Int,
              let maxCapacity = info[kIOPSMaxCapacityKey] as? Int,
              maxCapacity > 0 else {
            batteryState = .unavailable
            return
        }
        let percent = min(max(Int((Double(capacity) / Double(maxCapacity)) * 100), 0), 100)
        let isCharging = (info[kIOPSIsChargingKey] as? Bool) == true
        batteryState = .available(value: "\(percent)%", isCharging: isCharging)
    }
    
    private func updateNetwork() {
        let sample = networkSampler.sample(uptime: ProcessInfo.processInfo.systemUptime)
        if let rates = networkCalculator.sample(sample) {
            networkState = .available(
                download: formatRate(rates.downloadBytesPerSecond),
                upload: formatRate(rates.uploadBytesPerSecond)
            )
        } else {
            networkState = .unavailable
        }
    }

    private func formatRate(_ rate: Double) -> String {
        let bounded = min(max(rate, 0), Double(Int64.max))
        return byteFormatter.string(fromByteCount: Int64(bounded.rounded())) + "/s"
    }
    
    func updateTrash() {
        let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first!
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: [.totalFileAllocatedSizeKey])
            var totalSize: Int64 = 0
            for fileURL in fileURLs {
                let values = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                if let size = values.totalFileAllocatedSize {
                    totalSize += Int64(size)
                }
            }
            if totalSize == 0 {
                self.trashState = .empty
            } else {
                self.trashState = .content(byteFormatter.string(fromByteCount: totalSize))
            }
        } catch {
            self.trashState = .unauthorized
        }
    }
}
