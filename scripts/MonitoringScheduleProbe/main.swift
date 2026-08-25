import Foundation

private actor SerialSamplingProbe {
    private var isSampling = false
    private var didReenter = false

    func sample() -> Bool {
        if isSampling { didReenter = true }
        isSampling = true
        for _ in 0 ..< 10_000 { _ = 1 + 1 }
        isSampling = false
        return !Thread.isMainThread
    }

    func passed() -> Bool { !didReenter }
}

@MainActor
private final class ProjectionProbe {
    private(set) var projectedOnMainThread = false
    func apply() { projectedOnMainThread = Thread.isMainThread }
}

@main
struct MonitoringScheduleProbe {
    static func main() async {
        verifyCadence()
        verifyLifecycleCancellation()
        await verifySerialBackgroundSamplingAndMainProjection()
        print("MonitoringScheduleProbe: PASS")
    }

    private static func verifyCadence() {
        let cadence = MonitorCadence.production
        expect(cadence.fast == 1 && cadence.memory == 2, "fast and memory cadence")
        expect(cadence.slow == 15 && cadence.trash == 20, "slow and Trash cadence")

        var planner = MonitorSchedulePlanner(cadence: cadence)
        var counts: [MonitorGroup: Int] = [:]
        for second in 0 ... 40 {
            for group in planner.dueGroups(at: TimeInterval(second)) {
                counts[group, default: 0] += 1
            }
        }
        expect(counts[.fast] == 41, "fast group runs every second")
        expect(counts[.memory] == 21, "memory group runs every two seconds")
        expect(counts[.slow] == 3, "slow group runs every fifteen seconds")
        expect(counts[.trash] == 3, "Trash group runs every twenty seconds")
    }

    private static func verifyLifecycleCancellation() {
        var lifecycle = MonitoringLifecycle()
        let first = lifecycle.start()
        expect(first != nil, "first start creates a token")
        expect(lifecycle.start() == nil, "duplicate start is rejected")
        expect(first.map(lifecycle.accepts) == true, "active token is accepted")

        lifecycle.stop()
        expect(first.map(lifecycle.accepts) == false, "stop invalidates outstanding work")
        let second = lifecycle.start()
        expect(second != nil && second != first, "restart creates a new generation")
    }

    private static func verifySerialBackgroundSamplingAndMainProjection() async {
        let sampler = SerialSamplingProbe()
        let offMain = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0 ..< 16 { group.addTask { await sampler.sample() } }
            var values: [Bool] = []
            for await value in group { values.append(value) }
            return values
        }
        expect(offMain.allSatisfy { $0 }, "sampling actor stays off the main thread")
        let serialSamplingPassed = await sampler.passed()
        expect(serialSamplingPassed, "sampling actor prevents reentry")

        let projection = await MainActor.run { ProjectionProbe() }
        await projection.apply()
        let projectedOnMainThread = await MainActor.run { projection.projectedOnMainThread }
        expect(projectedOnMainThread, "UI projection runs on MainActor")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("MonitoringScheduleProbe: FAIL — \(message)\n", stderr)
            exit(1)
        }
    }
}
