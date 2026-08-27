import AppKit
import Combine
import Foundation

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var memoryUsedString = "0 GB"
    @Published private(set) var memoryTotalString = "16 GB"
    @Published private(set) var memoryPercent = 0.0
    @Published private(set) var memoryActiveString = "0 GB"
    @Published private(set) var storageFreeString = "0 GB"
    @Published private(set) var storageUsedPercent = 0.0
    @Published private(set) var cpuState: CPUState = .unavailable
    @Published private(set) var batteryState: BatteryState = .unavailable
    @Published private(set) var networkState: NetworkState = .unavailable
    @Published private(set) var thermalState: ThermalState = .unavailable
    @Published private(set) var trashState: TrashState = .unauthorized
    @Published private(set) var trashClearReport: TrashClearReport?
    @Published private(set) var samplingFailures: [MetricKind: MetricSamplingError] = [:]

    private let sampler: SystemMetricSampler
    private let capabilities: ProductCapabilities
    private let cadence: MonitorCadence
    private var monitoringTask: Task<Void, Never>?
    private var trashOperationTask: Task<Void, Never>?
    private var lifecycle = MonitoringLifecycle()
    private var wantsMonitoring = false
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    init(
        capabilities: ProductCapabilities = .current,
        sampler: SystemMetricSampler? = nil,
        cadence: MonitorCadence = .production
    ) {
        self.capabilities = capabilities
        self.sampler = sampler ?? SystemMetricSampler(capabilities: capabilities)
        self.cadence = cadence
        observeWorkspacePowerEvents()
    }

    deinit {
        monitoringTask?.cancel()
        trashOperationTask?.cancel()
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    func startMonitoring() {
        wantsMonitoring = true
        launchMonitoringTaskIfNeeded()
    }

    func stopMonitoring() {
        wantsMonitoring = false
        cancelMonitoringTask()
    }

    func authorizeTrash() {
        guard capabilities.supportsTrash else { return }
        guard trashOperationTask == nil else { return }
        trashState = .scanning
        let sampler = sampler
        trashOperationTask = Task { [weak self, sampler] in
            let selectedURL = await TrashAuthorizationPanel.chooseUserTrash()
            guard !Task.isCancelled else { return }
            let state: TrashState
            if let selectedURL {
                state = await sampler.authorizeTrash(at: selectedURL)
            } else {
                state = await sampler.trashAuthorizationCancelled()
            }
            guard !Task.isCancelled else { return }
            self?.trashState = state
            self?.trashOperationTask = nil
        }
    }

    func clearTrash() {
        guard capabilities.supportsTrash else { return }
        guard trashOperationTask == nil else { return }
        trashState = .scanning
        trashClearReport = nil
        let sampler = sampler
        trashOperationTask = Task { [weak self, sampler] in
            let report = await sampler.clearTrash()
            guard !Task.isCancelled else { return }
            self?.trashClearReport = report
            if report.failures.isEmpty {
                let projection = await sampler.sample(.trash)
                guard !Task.isCancelled else { return }
                self?.apply(projection)
            } else {
                let details = report.failures.map { "\($0.itemName): \($0.message)" }.joined(separator: "; ")
                self?.trashState = .error(details)
            }
            self?.trashOperationTask = nil
        }
    }

    private func launchMonitoringTaskIfNeeded() {
        guard monitoringTask == nil, let token = lifecycle.start() else { return }
        let sampler = sampler
        let cadence = cadence

        monitoringTask = Task { [weak self, sampler] in
            await sampler.resetBaselines()
            var planner = MonitorSchedulePlanner(cadence: cadence)

            while !Task.isCancelled {
                guard self?.lifecycle.accepts(token) == true else { return }
                let groups = planner.dueGroups(at: ProcessInfo.processInfo.systemUptime)

                for group in groups {
                    guard !Task.isCancelled else { return }
                    let projection = await sampler.sample(group)
                    guard self?.lifecycle.accepts(token) == true else { return }
                    self?.apply(projection)
                }

                do {
                    try await Task.sleep(nanoseconds: cadence.tickNanoseconds)
                } catch {
                    return
                }
            }
        }
    }

    private func cancelMonitoringTask() {
        lifecycle.stop()
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func apply(_ projection: MonitorProjection) {
        switch projection {
        case .fast(let snapshot):
            cpuState = snapshot.cpu
            networkState = snapshot.network
            thermalState = snapshot.thermal
            replaceFailures(for: [.cpu, .network, .thermal], with: snapshot.failures)

        case .memory(let result):
            switch result {
            case .success(let snapshot):
                memoryUsedString = snapshot.used
                memoryTotalString = snapshot.total
                memoryActiveString = snapshot.active
                memoryPercent = snapshot.fractionUsed
                samplingFailures[.memory] = nil
            case .failure(let error):
                samplingFailures[.memory] = error
            }

        case .slow(let snapshot):
            batteryState = snapshot.battery
            if let storage = snapshot.storage {
                storageFreeString = storage.available
                storageUsedPercent = storage.fractionUsed
            }
            replaceFailures(for: [.battery, .storage], with: snapshot.failures)

        case .trash(let state):
            trashState = state
            samplingFailures[.trash] = nil
        }
    }

    private func replaceFailures(
        for kinds: Set<MetricKind>,
        with failures: [MetricKind: MetricSamplingError]
    ) {
        for kind in kinds { samplingFailures[kind] = failures[kind] }
    }

    private func observeWorkspacePowerEvents() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.cancelMonitoringTask() }
        }
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.wantsMonitoring else { return }
                self.launchMonitoringTaskIfNeeded()
            }
        }
    }
}
