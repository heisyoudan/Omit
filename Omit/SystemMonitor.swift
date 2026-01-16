//
//  SystemMonitor.swift
//  Omit
//
//  Created by heisyoudan on 2026/1/16.
//

import Foundation
import SwiftUI
import Combine
import IOKit.ps

class SystemMonitor: ObservableObject {
    
    // --- 1. 发布给 UI 的数据 ---
    @Published var memoryUsedString: String = "0 GB"
    @Published var memoryTotalString: String = "16 GB"
    @Published var memoryPercent: Double = 0.0
    
    @Published var storageFreeString: String = "0 GB"
    @Published var storageUsedPercent: Double = 0.0
    
    @Published var cpuLoadString: String = "0%"
    
    @Published var batteryPercentString: String = "100%"
    @Published var batteryIcon: String = "battery.100"
    @Published var batteryColor: Color = .green
    
    @Published var networkSpeedString: String = "0 KB/s"
    
    @Published var trashSizeString: String = "Empty"
    
    // [新增] 权限状态标记
    @Published var hasTrashPermission: Bool = true
    
    // --- 2. 内部工具 ---
    private var timer: Timer?
    private let fileManager = FileManager.default
    
    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()
    
    private var lastNetworkBytes: UInt64 = 0
    private var lastCheckTime: TimeInterval = Date().timeIntervalSince1970
    
    private var prevCpuInfo: processor_info_array_t?
    private var prevCpuInfoCount: mach_msg_type_number_t = 0
    
    // --- 3. 初始化与清理 ---
    init() {
        checkPermission() // 启动时先检查一次权限
        startMonitoring()
        updateStats()
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        // 释放 CPU 信息内存
        if let prev = prevCpuInfo {
            let prevSize = Int(prevCpuInfoCount) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(prevSize))
        }
    }
    
    // [新增] 检查权限的方法
    func checkPermission() {
        let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first!
        do {
            // 尝试读取废纸篓目录，如果没报错就是有权限
            _ = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)
            DispatchQueue.main.async { self.hasTrashPermission = true }
        } catch {
            DispatchQueue.main.async { self.hasTrashPermission = false }
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
    
    // --- 4. 核心逻辑 ---
    // (A, B, C, D, E 省略，保持不变)
    // 请保留你之前的 Memory, Storage, CPU, Battery, Network 代码
    // 这里为了篇幅，我假设你保留了它们。如果丢失了请用上一个回复的代码。
    
    // A. 内存
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
            let used = UInt64(stats.active_count + stats.wire_count) * pageSize
            let total = ProcessInfo.processInfo.physicalMemory
            let percent = Double(used) / Double(total)
            self.memoryUsedString = byteFormatter.string(fromByteCount: Int64(used))
            self.memoryTotalString = byteFormatter.string(fromByteCount: Int64(total))
            self.memoryPercent = percent
        }
    }
    
    // B. 硬盘
    private func updateStorage() {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let capacity = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let used = Int64(capacity - available)
                self.storageFreeString = byteFormatter.string(fromByteCount: Int64(available))
                self.storageUsedPercent = Double(used) / Double(capacity)
            }
        } catch {}
    }
    
    // C. CPU
    private func updateCPU() {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCpuInfo)
        if result == KERN_SUCCESS {
            var totalUsage: Float = 0.0
            if let prevCpuInfo = prevCpuInfo {
                for i in 0 ..< Int32(numCPUs) {
                    let inUse = Int32(cpuInfo![Int(i) * Int(CPU_STATE_MAX) + Int(CPU_STATE_USER)])
                        - Int32(prevCpuInfo[Int(i) * Int(CPU_STATE_MAX) + Int(CPU_STATE_USER)])
                        + Int32(cpuInfo![Int(i) * Int(CPU_STATE_MAX) + Int(CPU_STATE_SYSTEM)])
                        - Int32(prevCpuInfo[Int(i) * Int(CPU_STATE_MAX) + Int(CPU_STATE_SYSTEM)])
                        + Int32(cpuInfo![Int(i) * Int(CPU_STATE_MAX) + Int(CPU_STATE_NICE)])
                        - Int32(prevCpuInfo[Int(i) * Int(CPU_STATE_MAX) + Int(CPU_STATE_NICE)])
                    let total = inUse + Int32(cpuInfo![Int(i) * Int(CPU_STATE_MAX) + Int(CPU_STATE_IDLE)])
                        - Int32(prevCpuInfo[Int(i) * Int(CPU_STATE_MAX) + Int(CPU_STATE_IDLE)])
                    if total > 0 { totalUsage += Float(inUse) / Float(total) }
                }
                let avgUsage = totalUsage / Float(numCPUs)
                self.cpuLoadString = String(format: "%.0f%%", avgUsage * 100)
            }
            if let prev = prevCpuInfo {
                let prevSize = Int(prevCpuInfoCount) * MemoryLayout<integer_t>.stride
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(prevSize))
            }
            prevCpuInfo = cpuInfo
            prevCpuInfoCount = numCpuInfo
        }
    }
    
    // D. 电池
    private func updateBattery() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        if let source = sources.first {
            let info = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as! [String: Any]
            if let capacity = info[kIOPSCurrentCapacityKey] as? Int,
               let maxCapacity = info[kIOPSMaxCapacityKey] as? Int {
                let percent = Int((Double(capacity) / Double(maxCapacity)) * 100)
                self.batteryPercentString = "\(percent)%"
                let isCharging = (info[kIOPSIsChargingKey] as? Bool) == true
                if isCharging {
                    self.batteryColor = .green; self.batteryIcon = "battery.100.bolt"
                } else {
                    self.batteryColor = percent < 20 ? .red : .green
                    if percent > 80 { self.batteryIcon = "battery.100" }
                    else if percent > 50 { self.batteryIcon = "battery.75" }
                    else if percent > 25 { self.batteryIcon = "battery.50" }
                    else { self.batteryIcon = "battery.25" }
                }
            }
        }
    }
    
    // E. 网络
    private func updateNetwork() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return }
        var ptr = ifaddr
        var totalBytes: UInt64 = 0
        while ptr != nil {
            let interface = ptr!.pointee
            if let name = String(validatingUTF8: interface.ifa_name),
               (name.hasPrefix("en") || name == "bridge0"),
               Int(interface.ifa_addr.pointee.sa_family) == AF_LINK,
               let data = interface.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                totalBytes += UInt64(networkData.ifi_ibytes)
            }
            ptr = interface.ifa_next
        }
        freeifaddrs(ifaddr)
        let now = Date().timeIntervalSince1970
        if lastNetworkBytes > 0 && totalBytes >= lastNetworkBytes {
            let diff = totalBytes - lastNetworkBytes
            let timeDiff = now - lastCheckTime
            if timeDiff > 0 {
                let speed = Double(diff) / timeDiff
                self.networkSpeedString = byteFormatter.string(fromByteCount: Int64(speed)) + "/s"
            }
        } else {
             self.networkSpeedString = byteFormatter.string(fromByteCount: 0) + "/s"
        }
        lastNetworkBytes = totalBytes
        lastCheckTime = now
    }
    
    // F. 废纸篓 (修改版：增加权限标记)
    func updateTrash() {
        let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first!
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: [.totalFileAllocatedSizeKey])
            // 如果能走到这里，说明有权限
            DispatchQueue.main.async { self.hasTrashPermission = true }
            
            var totalSize: Int64 = 0
            for fileURL in fileURLs {
                let values = try fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                if let size = values.totalFileAllocatedSize {
                    totalSize += Int64(size)
                }
            }
            if totalSize == 0 {
                self.trashSizeString = "Empty"
            } else {
                self.trashSizeString = byteFormatter.string(fromByteCount: totalSize)
            }
        } catch {
            // 如果报错，说明没权限
            DispatchQueue.main.async { self.hasTrashPermission = false }
            self.trashSizeString = "No Access"
        }
    }
    
    // G. 清空动作
    func emptyTrashAction() {
        let trashURL = fileManager.urls(for: .trashDirectory, in: .userDomainMask).first!
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: trashURL, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
            if let sound = NSSound(named: "Tink") { sound.play() }
            updateTrash()
        } catch {
            print("Empty Trash Failed: \(error)")
        }
    }
}
