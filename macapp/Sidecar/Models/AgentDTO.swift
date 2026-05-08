import Foundation

// Mirrors docs/protocol.md v0.1. Field names use snake_case via CodingKeys.

struct AgentInfo: Codable, Hashable {
    struct Agent: Codable, Hashable {
        let version: String
        let startedAt: Date
        enum CodingKeys: String, CodingKey {
            case version
            case startedAt = "started_at"
        }
    }
    struct Host: Codable, Hashable {
        let hostname: String
        let os: String
        let arch: String
        let kernel: String
        let platform: String
    }
    struct Tailnet: Codable, Hashable {
        let tailscaleIP4: String
        let tailscaleIP6: String
        let magicDNSName: String
        enum CodingKeys: String, CodingKey {
            case tailscaleIP4 = "tailscale_ip4"
            case tailscaleIP6 = "tailscale_ip6"
            case magicDNSName = "magicdns_name"
        }
    }
    let agent: Agent
    let host: Host
    let tailnet: Tailnet
    let capabilities: [String]
}

struct MetricsSnapshot: Codable, Hashable {
    let ts: Date
    let uptimeSeconds: UInt64
    let cpu: CPU
    let mem: Mem
    let load: Load?
    let disks: [Disk]
    let net: [NetIO]

    enum CodingKeys: String, CodingKey {
        case ts
        case uptimeSeconds = "uptime_seconds"
        case cpu, mem, load, disks, net
    }

    struct CPU: Codable, Hashable {
        let usagePercent: Double
        let cores: Int
        enum CodingKeys: String, CodingKey {
            case usagePercent = "usage_percent"
            case cores
        }
    }
    struct Mem: Codable, Hashable {
        let usedBytes: UInt64
        let totalBytes: UInt64
        let swapUsedBytes: UInt64?
        let swapTotalBytes: UInt64?
        enum CodingKeys: String, CodingKey {
            case usedBytes = "used_bytes"
            case totalBytes = "total_bytes"
            case swapUsedBytes = "swap_used_bytes"
            case swapTotalBytes = "swap_total_bytes"
        }
        var usageFraction: Double {
            totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
        }
    }
    struct Load: Codable, Hashable {
        let load1: Double
        let load5: Double
        let load15: Double
    }
    struct Disk: Codable, Hashable {
        let mount: String
        let fstype: String
        let usedBytes: UInt64
        let totalBytes: UInt64
        enum CodingKeys: String, CodingKey {
            case mount, fstype
            case usedBytes = "used_bytes"
            case totalBytes = "total_bytes"
        }
    }
    struct NetIO: Codable, Hashable {
        let name: String
        let rxBps: UInt64
        let txBps: UInt64
        let rxTotalBytes: UInt64
        let txTotalBytes: UInt64
        enum CodingKeys: String, CodingKey {
            case name
            case rxBps = "rx_bps"
            case txBps = "tx_bps"
            case rxTotalBytes = "rx_total_bytes"
            case txTotalBytes = "tx_total_bytes"
        }
    }
}

// JSONDecoder configured for the agent's RFC 3339 timestamps with optional
// fractional seconds.
extension JSONDecoder {
    static let sidecarAgent: JSONDecoder = {
        let d = JSONDecoder()
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = withFraction.date(from: s) { return date }
            if let date = plain.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "unrecognized date \(s)")
        }
        return d
    }()
}
