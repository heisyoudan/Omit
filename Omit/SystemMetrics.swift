import Foundation

struct MemoryCounters: Equatable {
    let active: UInt64
    let inactive: UInt64
    let speculative: UInt64
    let wired: UInt64
    let compressed: UInt64
    let purgeable: UInt64
    let external: UInt64
    let total: UInt64
}

struct MemoryUsage: Equatable {
    let used: UInt64
    let active: UInt64
    let total: UInt64
    let fractionUsed: Double
}

enum MemoryUsageCalculator {
    /// Product semantic: an estimated resident footprint useful for a compact status view.
    /// It deliberately does not promise byte-for-byte parity with Activity Monitor.
    static func calculate(_ counters: MemoryCounters) -> MemoryUsage {
        let gross = saturatingSum([
            counters.active,
            counters.inactive,
            counters.speculative,
            counters.wired,
            counters.compressed
        ])
        let reclaimable = saturatingSum([counters.purgeable, counters.external])
        let estimatedUsed = gross >= reclaimable ? gross - reclaimable : 0
        let used = min(estimatedUsed, counters.total)
        let fraction = counters.total == 0 ? 0 : Double(used) / Double(counters.total)

        return MemoryUsage(
            used: used,
            active: min(counters.active, counters.total),
            total: counters.total,
            fractionUsed: min(max(fraction.isFinite ? fraction : 0, 0), 1)
        )
    }

    private static func saturatingSum(_ values: [UInt64]) -> UInt64 {
        values.reduce(0) { partial, value in
            let (sum, overflow) = partial.addingReportingOverflow(value)
            return overflow ? UInt64.max : sum
        }
    }
}

struct CPUTicks: Equatable {
    let user: UInt64
    let system: UInt64
    let nice: UInt64
    let idle: UInt64
}

struct CPUUsageCalculator {
    private(set) var previous: [CPUTicks]?

    mutating func sample(_ current: [CPUTicks]) -> Double? {
        defer { previous = current }
        guard let previous,
              !current.isEmpty,
              previous.count == current.count else {
            return nil
        }

        var totalUsage = 0.0
        for (old, new) in zip(previous, current) {
            guard let user = delta(new.user, old.user),
                  let system = delta(new.system, old.system),
                  let nice = delta(new.nice, old.nice),
                  let idle = delta(new.idle, old.idle) else {
                return nil
            }

            let busy = saturatingSum([user, system, nice])
            let total = saturatingSum([busy, idle])
            guard total > 0 else { return nil }
            totalUsage += Double(busy) / Double(total)
        }

        let average = totalUsage / Double(current.count)
        guard average.isFinite else { return nil }
        return min(max(average, 0), 1)
    }

    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64? {
        current >= previous ? current - previous : nil
    }

    private func saturatingSum(_ values: [UInt64]) -> UInt64 {
        values.reduce(0) { partial, value in
            let (sum, overflow) = partial.addingReportingOverflow(value)
            return overflow ? UInt64.max : sum
        }
    }
}

struct NetworkCounterSample: Equatable {
    let interfaceName: String
    let receivedBytes: UInt64
    let transmittedBytes: UInt64
    let uptime: TimeInterval
}

struct NetworkRates: Equatable {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

struct NetworkRateCalculator {
    var maximumInterval: TimeInterval = 10
    private(set) var previous: NetworkCounterSample?

    mutating func sample(_ current: NetworkCounterSample?) -> NetworkRates? {
        guard let current else {
            previous = nil
            return nil
        }
        defer { previous = current }

        guard let previous,
              previous.interfaceName == current.interfaceName,
              current.receivedBytes >= previous.receivedBytes,
              current.transmittedBytes >= previous.transmittedBytes else {
            return nil
        }

        let interval = current.uptime - previous.uptime
        guard interval > 0, interval <= maximumInterval else { return nil }

        let download = Double(current.receivedBytes - previous.receivedBytes) / interval
        let upload = Double(current.transmittedBytes - previous.transmittedBytes) / interval
        guard download.isFinite, upload.isFinite else { return nil }

        return NetworkRates(
            downloadBytesPerSecond: max(download, 0),
            uploadBytesPerSecond: max(upload, 0)
        )
    }
}
