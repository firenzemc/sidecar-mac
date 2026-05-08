import Foundation

enum MockData {
    static func devices() -> [Device] {
        [
            mock(id: "n1", host: "hayabusa", os: "darwin", v4: "100.64.1.10", agent: true),
            mock(id: "n2", host: "konata",   os: "linux",  v4: "100.64.1.11", agent: true),
            mock(id: "n3", host: "yotsuba",  os: "windows", v4: "100.64.1.12", agent: true),
            mock(id: "n4", host: "minato",   os: "darwin", v4: "100.64.1.13", agent: false),
            mock(id: "n5", host: "wakaba",   os: "linux",  v4: "100.64.1.14", agent: true, online: false),
        ]
    }

    static func snapshot(seed: Int, at date: Date = .now) -> MetricsSnapshot {
        var rng = SeededRandom(seed: UInt64(seed) &* UInt64(Int(date.timeIntervalSince1970) / 5))
        let cpu = rng.double(in: 5...75)
        let memTotal: UInt64 = 32 * 1024 * 1024 * 1024
        let memUsed = UInt64(Double(memTotal) * rng.double(in: 0.2...0.7))
        return MetricsSnapshot(
            ts: date,
            uptimeSeconds: UInt64(rng.double(in: 3600...604800)),
            cpu: .init(usagePercent: (cpu * 10).rounded() / 10, cores: 10),
            mem: .init(usedBytes: memUsed, totalBytes: memTotal, swapUsedBytes: 0, swapTotalBytes: 0),
            load: .init(load1: rng.double(in: 0.1...3), load5: rng.double(in: 0.1...2.5), load15: rng.double(in: 0.1...2)),
            disks: [
                .init(mount: "/", fstype: "apfs", usedBytes: 412 * 1024 * 1024 * 1024, totalBytes: 994 * 1024 * 1024 * 1024)
            ],
            net: [
                .init(name: "en0",
                      rxBps: UInt64(rng.double(in: 0...20_000_000)),
                      txBps: UInt64(rng.double(in: 0...8_000_000)),
                      rxTotalBytes: UInt64(rng.double(in: 1e9...2e10)),
                      txTotalBytes: UInt64(rng.double(in: 1e8...5e9)))
            ]
        )
    }

    private static func mock(id: String, host: String, os: String, v4: String,
                             agent: Bool, online: Bool = true) -> Device {
        Device(
            id: id,
            hostname: host,
            os: os,
            magicDNSName: "\(host).tailnet-mock.ts.net",
            tailscaleIPv4: v4,
            tailscaleIPv6: nil,
            agentBaseURL: agent ? URL(string: "http://\(host).tailnet-mock.ts.net:8765") : nil,
            isOnline: online,
            hasAgent: agent
        )
    }
}

// Deterministic RNG so the mock UI doesn't jitter every frame; reseeded from
// the current 5s bucket, so values still drift visibly during demo.
private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { self.state = seed | 1 }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(UInt64(1) << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}
