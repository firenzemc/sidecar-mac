import Foundation

struct Device: Identifiable, Hashable {
    let id: String              // Tailscale node ID (stable)
    var hostname: String
    var os: String              // "darwin" / "linux" / "windows" / ...
    var magicDNSName: String?   // e.g., "hayabusa.tailnet-xxxx.ts.net"
    var tailscaleIPv4: String?
    var tailscaleIPv6: String?

    /// URL of the agent's HTTP endpoint, if discovery confirmed one is reachable.
    var agentBaseURL: URL?

    var isOnline: Bool          // tailnet reachability (from `tailscale status`)
    var hasAgent: Bool          // did /healthz respond?

    var displayName: String { hostname }
}

struct DeviceState {
    var lastInfo: AgentInfo?
    var latest: MetricsSnapshot?
    var lastPolledAt: Date?
    var lastError: String?
    var history: [MetricsSnapshot] = []   // ring buffer; cap enforced by caller

    static let empty = DeviceState()
}
