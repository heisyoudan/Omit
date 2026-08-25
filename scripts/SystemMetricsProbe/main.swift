import Foundation

@main
struct SystemMetricsProbe {
    static func main() {
        verifyMemoryBoundaries()
        verifyCPUDeltas()
        verifyNetworkBaselines()
        verifyLiveNetworkSampler()
        print("SystemMetricsProbe: PASS")
    }

    private static func verifyMemoryBoundaries() {
        let underflow = MemoryUsageCalculator.calculate(MemoryCounters(
            active: 1, inactive: 1, speculative: 0, wired: 0, compressed: 0,
            purgeable: 10, external: 10, total: 100
        ))
        expect(underflow.used == 0 && underflow.fractionUsed == 0, "memory underflow clamps to zero")

        let overflow = MemoryUsageCalculator.calculate(MemoryCounters(
            active: .max, inactive: .max, speculative: .max, wired: .max, compressed: .max,
            purgeable: 0, external: 0, total: 128
        ))
        expect(overflow.used == 128 && overflow.fractionUsed == 1, "memory overflow clamps to total")
    }

    private static func verifyCPUDeltas() {
        var calculator = CPUUsageCalculator()
        expect(calculator.sample([CPUTicks(user: 10, system: 5, nice: 0, idle: 85)]) == nil, "CPU first sample is unavailable")
        let usage = calculator.sample([CPUTicks(user: 20, system: 10, nice: 0, idle: 170)])
        expect(abs((usage ?? -1) - 0.15) < 0.0001, "CPU valid delta is calculated")
        expect(calculator.sample([CPUTicks(user: 1, system: 1, nice: 0, idle: 1)]) == nil, "CPU reset is unavailable")
    }

    private static func verifyNetworkBaselines() {
        var calculator = NetworkRateCalculator()
        let first = NetworkCounterSample(interfaceName: "en0", receivedBytes: 1_000, transmittedBytes: 2_000, uptime: 1)
        expect(calculator.sample(first) == nil, "network first sample is unavailable")

        let second = NetworkCounterSample(interfaceName: "en0", receivedBytes: 3_000, transmittedBytes: 3_000, uptime: 3)
        let rates = calculator.sample(second)
        expect(rates == NetworkRates(downloadBytesPerSecond: 1_000, uploadBytesPerSecond: 500), "RX and TX are independent")

        let switched = NetworkCounterSample(interfaceName: "utun0", receivedBytes: 100, transmittedBytes: 200, uptime: 4)
        expect(calculator.sample(switched) == nil, "interface switch establishes a new baseline")
        expect(calculator.sample(nil) == nil && calculator.previous == nil, "disconnect clears the baseline")

        _ = calculator.sample(NetworkCounterSample(interfaceName: "en0", receivedBytes: 5_000, transmittedBytes: 5_000, uptime: 10))
        expect(calculator.sample(NetworkCounterSample(interfaceName: "en0", receivedBytes: 6_000, transmittedBytes: 6_000, uptime: 30)) == nil, "sleep gap establishes a new baseline")
        expect(calculator.sample(NetworkCounterSample(interfaceName: "en0", receivedBytes: 10, transmittedBytes: 10, uptime: 31)) == nil, "counter reset establishes a new baseline")
    }

    private static func verifyLiveNetworkSampler() {
        let sample = NetworkCounterSampler().sample(uptime: ProcessInfo.processInfo.systemUptime)
        expect(sample?.interfaceName.isEmpty == false, "primary routed interface has 64-bit counters")
        if let sample {
            print("NetworkCounterSampler: interface=\(sample.interfaceName) rx=\(sample.receivedBytes) tx=\(sample.transmittedBytes)")
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("SystemMetricsProbe: FAIL — \(message)\n", stderr)
            exit(1)
        }
    }
}
