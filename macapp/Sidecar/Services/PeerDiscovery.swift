import Foundation

enum PeerDiscovery {
    /// Default agent port (matches `agent` defaults).
    static let agentPort = 8765

    /// Resolves the tailnet roster, then probes each peer for an agent.
    static func discover(port: Int = agentPort) async throws -> [Device] {
        let status = try await TailscaleCLI.status()
        var devices = status.allDevices()

        // Probe each device for an agent in parallel.
        await withTaskGroup(of: (Int, Device).self) { group in
            for (idx, device) in devices.enumerated() {
                group.addTask {
                    var d = device
                    if let url = bestAgentURL(for: device, port: port) {
                        let client = AgentClient(baseURL: url)
                        if await client.healthz() {
                            d.agentBaseURL = url
                            d.hasAgent = true
                        }
                    }
                    return (idx, d)
                }
            }
            for await (idx, d) in group {
                devices[idx] = d
            }
        }
        return devices
    }

    /// Prefers MagicDNS name, falls back to v4 then v6.
    private static func bestAgentURL(for device: Device, port: Int) -> URL? {
        if let dns = device.magicDNSName, !dns.isEmpty,
           let url = URL(string: "http://\(dns):\(port)") {
            return url
        }
        if let v4 = device.tailscaleIPv4,
           let url = URL(string: "http://\(v4):\(port)") {
            return url
        }
        if let v6 = device.tailscaleIPv6,
           let url = URL(string: "http://[\(v6)]:\(port)") {
            return url
        }
        return nil
    }
}
