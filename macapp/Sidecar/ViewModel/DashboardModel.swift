import Foundation
import Observation

enum DataSource: Hashable {
    case live
    case mock
}

@Observable
@MainActor
final class DashboardModel {
    /// Cap on how many snapshots we retain per device, used for sparkline history later.
    static let historyCapacity = 60

    var devices: [Device] = []
    var states: [String: DeviceState] = [:]
    var theme: Theme = .grid
    var dataSource: DataSource = .live {
        didSet { Task { await applyDataSourceChange() } }
    }

    var pollInterval: TimeInterval = 5
    var discoveryInterval: TimeInterval = 30

    var lastDiscoveryError: String?

    private var poller: Poller?
    private var discoveryTask: Task<Void, Never>?
    private var mockTask: Task<Void, Never>?

    func start() async {
        await applyDataSourceChange()
    }

    func refreshNow() async {
        switch dataSource {
        case .live:
            await runDiscoveryOnce()
        case .mock:
            applyMockSnapshot()
        }
    }

    private func applyDataSourceChange() async {
        // Reset everything when toggling.
        await poller?.stop()
        poller = nil
        discoveryTask?.cancel()
        discoveryTask = nil
        mockTask?.cancel()
        mockTask = nil
        states.removeAll()
        lastDiscoveryError = nil

        switch dataSource {
        case .live:
            await startLive()
        case .mock:
            startMock()
        }
    }

    private func startLive() async {
        let p = Poller(interval: pollInterval) { [weak self] id, result in
            await self?.recordResult(deviceID: id, result: result)
        }
        await p.start()
        self.poller = p

        discoveryTask = Task { [weak self] in
            guard let self else { return }
            await self.runDiscoveryOnce()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self.discoveryInterval))
                if Task.isCancelled { break }
                await self.runDiscoveryOnce()
            }
        }
    }

    private func runDiscoveryOnce() async {
        do {
            let found = try await PeerDiscovery.discover()
            self.devices = found
            self.lastDiscoveryError = nil
            await poller?.update(devices: found, interval: pollInterval)
        } catch {
            self.lastDiscoveryError = error.localizedDescription
        }
    }

    private func startMock() {
        devices = MockData.devices()
        applyMockSnapshot()
        mockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { break }
                self?.applyMockSnapshot()
            }
        }
    }

    private func applyMockSnapshot() {
        for (i, d) in devices.enumerated() {
            guard d.hasAgent, d.isOnline else { continue }
            let snap = MockData.snapshot(seed: i + 1)
            recordSnapshot(deviceID: d.id, snapshot: snap)
        }
    }

    private func recordResult(deviceID: String, result: Result<MetricsSnapshot, Error>) {
        switch result {
        case .success(let snap):
            recordSnapshot(deviceID: deviceID, snapshot: snap)
        case .failure(let err):
            var s = states[deviceID] ?? .empty
            s.lastError = err.localizedDescription
            s.lastPolledAt = .now
            states[deviceID] = s
        }
    }

    private func recordSnapshot(deviceID: String, snapshot: MetricsSnapshot) {
        var s = states[deviceID] ?? .empty
        s.latest = snapshot
        s.lastError = nil
        s.lastPolledAt = .now
        s.history.append(snapshot)
        if s.history.count > Self.historyCapacity {
            s.history.removeFirst(s.history.count - Self.historyCapacity)
        }
        states[deviceID] = s
    }
}
