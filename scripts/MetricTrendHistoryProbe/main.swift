import Foundation

@main
struct MetricTrendHistoryProbe {
    static func main() {
        verifyCapacityAndOrdering()
        verifyInvalidSampleResets()
        verifySessionReset()
        verifySharedNetworkScale()
        print("MetricTrendHistoryProbe: PASS")
    }

    private static func verifyCapacityAndOrdering() {
        var history = MetricTrendHistory(capacity: 30)
        for value in 0 ..< 40 {
            history.recordCPU(Double(value) / 100)
            history.recordNetwork(download: Double(value), upload: Double(value * 2))
        }
        expect(history.cpuFractions.count == 30, "CPU history is bounded to 30")
        expect(history.networkSamples.count == 30, "Network history is bounded to 30")
        expect(history.cpuFractions.first == 0.10 && history.cpuFractions.last == 0.39, "CPU keeps newest samples in order")
        expect(history.networkSamples.first?.downloadBytesPerSecond == 10, "Network keeps newest samples in order")
    }

    private static func verifyInvalidSampleResets() {
        var history = MetricTrendHistory()
        history.recordCPU(0.5)
        history.recordCPU(0.6)
        history.recordCPU(nil)
        expect(history.cpuFractions.isEmpty, "unavailable CPU clears the line")

        history.recordNetwork(download: 10, upload: 20)
        history.recordNetwork(download: 20, upload: 30)
        history.recordNetwork(download: -1, upload: 10)
        expect(history.networkSamples.isEmpty, "invalid Network clears both lines")
    }

    private static func verifySessionReset() {
        var history = MetricTrendHistory()
        history.recordCPU(0.4)
        history.recordNetwork(download: 1, upload: 2)
        history.reset()
        expect(history.cpuFractions.isEmpty && history.networkSamples.isEmpty, "session reset clears all history")
    }

    private static func verifySharedNetworkScale() {
        let maximum = NetworkTrendScale.sharedMaximum(download: [1, 20, 5], upload: [2, 80, 3])
        expect(maximum == 80, "download and upload share one maximum")
        expect(NetworkTrendScale.sharedMaximum(download: [], upload: []) == 1, "empty shared scale stays finite")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("MetricTrendHistoryProbe: FAIL — \(message)\n", stderr)
            exit(1)
        }
    }
}
