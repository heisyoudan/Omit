#if DEBUG
import Foundation

nonisolated struct DebugCPUTrace: Codable, Sendable {
    let ticks: [DebugCPUTicks]
    let calculatedFraction: Double?
    let availability: String
    let error: String?
}

nonisolated struct DebugCPUTicks: Codable, Sendable {
    let user: UInt64
    let system: UInt64
    let nice: UInt64
    let idle: UInt64
}

nonisolated struct DebugMemoryTrace: Codable, Sendable {
    let activePages: UInt64
    let inactivePages: UInt64
    let speculativePages: UInt64
    let wiredPages: UInt64
    let compressedPages: UInt64
    let purgeablePages: UInt64
    let externalPages: UInt64
    let pageSize: UInt64
    let physicalMemory: UInt64
    let calculatedUsedBytes: UInt64?
    let calculatedActiveBytes: UInt64?
    let calculatedFraction: Double?
    let error: String?
}

nonisolated struct DebugStorageTrace: Codable, Sendable {
    let volumeIdentifier: String?
    let totalCapacity: Int64?
    let availableCapacity: Int64?
    let importantUsageCapacity: Int64?
    let opportunisticUsageCapacity: Int64?
    let calculatedFraction: Double?
    let error: String?
}

nonisolated struct DebugNetworkTrace: Codable, Sendable {
    let interfaceName: String?
    let receivedBytes: UInt64?
    let transmittedBytes: UInt64?
    let counterUptime: TimeInterval?
    let calculatedDownloadBytesPerSecond: Double?
    let calculatedUploadBytesPerSecond: Double?
    let baselineResetReason: String?
}

nonisolated struct DebugBatteryTrace: Codable, Sendable {
    let batteryPresent: Bool
    let providingPowerSourceType: String?
    let currentCapacity: Int?
    let maxCapacity: Int?
    let isCharging: Bool?
    let mappedState: String
}

nonisolated struct DebugThermalTrace: Codable, Sendable {
    let rawState: String
    let mappedState: String
}

nonisolated struct DebugMetricTraceRecord: Codable, Sendable {
    let schemaVersion: Int
    let event: String
    let marker: String?
    let sequence: UInt64
    let group: String?
    let wallClockUnix: TimeInterval
    let startUptime: TimeInterval
    let endUptime: TimeInterval
    let inFlightCount: Int
    let generation: UInt64
    let fixtureName: String?
    let cpu: DebugCPUTrace?
    let memory: DebugMemoryTrace?
    let storage: DebugStorageTrace?
    let network: DebugNetworkTrace?
    let battery: DebugBatteryTrace?
    let thermal: DebugThermalTrace?

    init(
        event: String,
        marker: String? = nil,
        sequence: UInt64,
        group: String? = nil,
        wallClockUnix: TimeInterval = Date().timeIntervalSince1970,
        startUptime: TimeInterval = ProcessInfo.processInfo.systemUptime,
        endUptime: TimeInterval = ProcessInfo.processInfo.systemUptime,
        inFlightCount: Int = 0,
        generation: UInt64 = 0,
        fixtureName: String? = nil,
        cpu: DebugCPUTrace? = nil,
        memory: DebugMemoryTrace? = nil,
        storage: DebugStorageTrace? = nil,
        network: DebugNetworkTrace? = nil,
        battery: DebugBatteryTrace? = nil,
        thermal: DebugThermalTrace? = nil
    ) {
        self.schemaVersion = 1
        self.event = event
        self.marker = marker
        self.sequence = sequence
        self.group = group
        self.wallClockUnix = wallClockUnix
        self.startUptime = startUptime
        self.endUptime = endUptime
        self.inFlightCount = inFlightCount
        self.generation = generation
        self.fixtureName = fixtureName
        self.cpu = cpu
        self.memory = memory
        self.storage = storage
        self.network = network
        self.battery = battery
        self.thermal = thermal
    }
}

actor DebugMetricTraceSink {
    private let fileHandle: FileHandle
    private let ownsFileHandle: Bool
    private let encoder: JSONEncoder

    init(fileHandle: FileHandle, ownsFileHandle: Bool = false) {
        self.fileHandle = fileHandle
        self.ownsFileHandle = ownsFileHandle
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    }

    deinit {
        if ownsFileHandle { try? fileHandle.close() }
    }

    static func standardOutput() -> DebugMetricTraceSink {
        DebugMetricTraceSink(fileHandle: .standardOutput)
    }

    static func file(at url: URL) throws -> DebugMetricTraceSink {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        return DebugMetricTraceSink(fileHandle: handle, ownsFileHandle: true)
    }

    static func fromEnvironment() -> DebugMetricTraceSink? {
        guard let path = ProcessInfo.processInfo.environment["OMIT_DEBUG_METRICS_JSONL"], !path.isEmpty else {
            return nil
        }
        return try? file(at: URL(fileURLWithPath: path))
    }

    func emit(_ record: DebugMetricTraceRecord) {
        guard var data = try? encoder.encode(record) else { return }
        data.append(0x0A)
        try? fileHandle.write(contentsOf: data)
    }
}
#endif
