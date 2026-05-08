import Foundation

/// Polls every device with an agent at a fixed cadence and reports results.
/// Runs as a single async loop; cancel by calling `stop()` or task cancellation.
actor Poller {
    typealias OnResult = @Sendable (String, Result<MetricsSnapshot, Error>) async -> Void

    private(set) var interval: TimeInterval
    private var task: Task<Void, Never>?
    private var devices: [Device] = []
    private let onResult: OnResult

    init(interval: TimeInterval = 5, onResult: @escaping OnResult) {
        self.interval = interval
        self.onResult = onResult
    }

    func update(devices: [Device], interval: TimeInterval? = nil) {
        self.devices = devices.filter { $0.hasAgent && $0.agentBaseURL != nil }
        if let interval { self.interval = interval }
    }

    func start() {
        guard task == nil else { return }
        let initial = self.interval
        task = Task { [weak self] in
            await self?.run(initial: initial)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func run(initial: TimeInterval) async {
        await tick()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(self.interval))
            if Task.isCancelled { break }
            await tick()
        }
    }

    private func tick() async {
        let snapshot = devices
        await withTaskGroup(of: Void.self) { group in
            for d in snapshot {
                guard let url = d.agentBaseURL else { continue }
                let id = d.id
                let cb = onResult
                group.addTask {
                    let client = AgentClient(baseURL: url)
                    do {
                        let m = try await client.metrics()
                        await cb(id, .success(m))
                    } catch {
                        await cb(id, .failure(error))
                    }
                }
            }
        }
    }
}
