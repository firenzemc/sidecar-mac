import Foundation

struct AgentClient {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    enum AgentError: Error, LocalizedError {
        case unexpectedStatus(Int)
        case majorMismatch(String)

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let s): return "agent returned HTTP \(s)"
            case .majorMismatch(let v):    return "incompatible agent protocol \(v)"
            }
        }
    }

    func healthz(timeout: TimeInterval = 1.5) async -> Bool {
        var request = URLRequest(url: baseURL.appendingPathComponent("healthz"))
        request.timeoutInterval = timeout
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        } catch {
            return false
        }
    }

    func info(timeout: TimeInterval = 5) async throws -> AgentInfo {
        try await get(path: "info", timeout: timeout)
    }

    func metrics(timeout: TimeInterval = 5) async throws -> MetricsSnapshot {
        try await get(path: "metrics", timeout: timeout)
    }

    private func get<T: Decodable>(path: String, timeout: TimeInterval) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.timeoutInterval = timeout

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AgentError.unexpectedStatus(0)
        }
        guard http.statusCode == 200 else {
            throw AgentError.unexpectedStatus(http.statusCode)
        }
        if let proto = http.value(forHTTPHeaderField: "X-Sidecar-Agent"),
           !proto.hasPrefix("v0.") {
            throw AgentError.majorMismatch(proto)
        }
        return try JSONDecoder.sidecarAgent.decode(T.self, from: data)
    }
}
