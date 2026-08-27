import Foundation

nonisolated enum MonitorGroup: CaseIterable, Equatable, Sendable {
    case fast
    case memory
    case slow
    case trash
}

nonisolated struct MonitorCadence: Equatable, Sendable {
    let tick: TimeInterval
    let fast: TimeInterval
    let memory: TimeInterval
    let slow: TimeInterval
    let trash: TimeInterval

    static let production = MonitorCadence(tick: 1, fast: 1, memory: 2, slow: 15, trash: 20)

    var tickNanoseconds: UInt64 {
        UInt64(max(tick, 0.05) * 1_000_000_000)
    }

    func interval(for group: MonitorGroup) -> TimeInterval {
        switch group {
        case .fast: fast
        case .memory: memory
        case .slow: slow
        case .trash: trash
        }
    }
}

nonisolated struct MonitorSchedulePlanner: Sendable {
    let cadence: MonitorCadence
    private(set) var lastRun: [MonitorGroup: TimeInterval] = [:]

    mutating func dueGroups(at uptime: TimeInterval) -> [MonitorGroup] {
        MonitorGroup.allCases.filter { group in
            guard let previous = lastRun[group] else {
                lastRun[group] = uptime
                return true
            }
            guard uptime - previous >= cadence.interval(for: group) else { return false }
            lastRun[group] = uptime
            return true
        }
    }
}

nonisolated struct MonitoringLifecycle: Equatable, Sendable {
    nonisolated struct Token: Equatable, Sendable {
        fileprivate let generation: UInt64
    }

    private(set) var isRunning = false
    private var generation: UInt64 = 0

    mutating func start() -> Token? {
        guard !isRunning else { return nil }
        isRunning = true
        generation &+= 1
        return Token(generation: generation)
    }

    mutating func stop() {
        isRunning = false
        generation &+= 1
    }

    func accepts(_ token: Token) -> Bool {
        isRunning && token.generation == generation
    }

    #if DEBUG
    var debugGeneration: UInt64 { generation }
    #endif
}
