import Foundation

enum TailscaleCLI {
    /// Common locations the `tailscale` binary can live in.
    private static let candidatePaths = [
        "/usr/local/bin/tailscale",
        "/opt/homebrew/bin/tailscale",
        "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
    ]

    enum CLIError: Error, LocalizedError {
        case notFound
        case invalidJSON(underlying: Error)
        case nonZeroExit(code: Int32, stderr: String)

        var errorDescription: String? {
            switch self {
            case .notFound:
                return "tailscale CLI not found in PATH or known locations."
            case .invalidJSON(let e):
                return "tailscale status output not parseable: \(e.localizedDescription)"
            case .nonZeroExit(let code, let stderr):
                return "tailscale exited \(code): \(stderr)"
            }
        }
    }

    static func resolveBinary() -> URL? {
        let fm = FileManager.default
        for path in candidatePaths where fm.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    /// Returns the parsed `tailscale status --json` output.
    static func status() async throws -> TailscaleStatus {
        guard let bin = resolveBinary() else { throw CLIError.notFound }

        let process = Process()
        process.executableURL = bin
        process.arguments = ["status", "--json"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let msg = String(data: errData, encoding: .utf8) ?? ""
            throw CLIError.nonZeroExit(code: process.terminationStatus, stderr: msg)
        }

        do {
            return try JSONDecoder().decode(TailscaleStatus.self, from: outData)
        } catch {
            throw CLIError.invalidJSON(underlying: error)
        }
    }
}

// Minimal subset of `tailscale status --json`. Tailscale's full schema is large
// and changes; we intentionally only decode what we need.
struct TailscaleStatus: Codable {
    struct Peer: Codable {
        let ID: String
        let HostName: String?
        let DNSName: String?            // FQDN with trailing dot, e.g. "host.tailnet.ts.net."
        let OS: String?
        let TailscaleIPs: [String]?
        let Online: Bool?
    }
    let Self: Peer?
    let Peer: [String: Peer]?
}

extension TailscaleStatus {
    /// Self + every peer, normalized into Device records.
    func allDevices() -> [Device] {
        var out: [Device] = []
        if let s = Self, let dev = Self.toDevice(s) {
            out.append(dev)
        }
        for (_, p) in Peer ?? [:] {
            if let dev = Self.toDevice(p) {
                out.append(dev)
            }
        }
        return out.sorted { $0.hostname.localizedCompare($1.hostname) == .orderedAscending }
    }

    private static func toDevice(_ p: Peer) -> Device? {
        guard let host = p.HostName, !host.isEmpty else { return nil }
        let ips = p.TailscaleIPs ?? []
        let v4 = ips.first { $0.contains(".") }
        let v6 = ips.first { $0.contains(":") }
        let dns = p.DNSName.map { $0.hasSuffix(".") ? String($0.dropLast()) : $0 }
        return Device(
            id: p.ID,
            hostname: host,
            os: p.OS ?? "",
            magicDNSName: dns,
            tailscaleIPv4: v4,
            tailscaleIPv6: v6,
            agentBaseURL: nil,
            isOnline: p.Online ?? false,
            hasAgent: false
        )
    }
}
