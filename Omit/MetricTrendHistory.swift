import Foundation

nonisolated struct NetworkTrendSample: Equatable, Sendable {
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

nonisolated struct MetricTrendHistory: Equatable, Sendable {
    let capacity: Int
    private(set) var cpuFractions: [Double] = []
    private(set) var networkSamples: [NetworkTrendSample] = []

    init(capacity: Int = 30) {
        self.capacity = max(capacity, 1)
    }

    mutating func recordCPU(_ fraction: Double?) {
        guard let fraction, fraction.isFinite, (0 ... 1).contains(fraction) else {
            cpuFractions.removeAll(keepingCapacity: true)
            return
        }
        append(fraction, to: &cpuFractions)
    }

    mutating func recordNetwork(download: Double?, upload: Double?) {
        guard let download, let upload,
              download.isFinite, upload.isFinite,
              download >= 0, upload >= 0 else {
            networkSamples.removeAll(keepingCapacity: true)
            return
        }
        append(NetworkTrendSample(downloadBytesPerSecond: download, uploadBytesPerSecond: upload), to: &networkSamples)
    }

    mutating func reset() {
        cpuFractions.removeAll(keepingCapacity: true)
        networkSamples.removeAll(keepingCapacity: true)
    }

    private func append<T>(_ value: T, to values: inout [T]) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst(values.count - capacity)
        }
    }
}

nonisolated enum NetworkTrendScale {
    static func sharedMaximum(download: [Double], upload: [Double]) -> Double {
        let maximum = (download + upload).filter { $0.isFinite && $0 >= 0 }.max() ?? 0
        return max(maximum, 1)
    }
}
