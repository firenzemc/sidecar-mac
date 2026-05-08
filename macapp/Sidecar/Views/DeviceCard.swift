import SwiftUI

struct DeviceCard: View {
    @Environment(DashboardModel.self) private var model
    let device: Device
    let state: DeviceState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider().background(model.theme.cardBorder)
            metrics
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.cardCorner, style: .continuous)
                .fill(model.theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.cardCorner, style: .continuous)
                .stroke(model.theme.cardBorder, lineWidth: 1)
        )
        .shadow(color: model.theme.accent.opacity(0.08), radius: 6, x: 0, y: 1)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: osSymbol(for: device.os))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(model.theme.accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(Tokens.monoDigits)
                    .foregroundStyle(model.theme.brightText)
                Text(device.tailscaleIPv4 ?? device.magicDNSName ?? "—")
                    .font(Tokens.monoSmall)
                    .foregroundStyle(model.theme.dimText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            statusDot
        }
    }

    @ViewBuilder
    private var metrics: some View {
        if !device.hasAgent {
            Text(device.isOnline ? "no agent" : "offline")
                .font(Tokens.monoSmall)
                .foregroundStyle(model.theme.dimText)
        } else if let snap = state.latest {
            VStack(alignment: .leading, spacing: 8) {
                Bar(label: "CPU", value: snap.cpu.usagePercent / 100, trailing: percent(snap.cpu.usagePercent))
                Bar(label: "MEM", value: snap.mem.usageFraction, trailing: percent(snap.mem.usageFraction * 100))
                netRow(snap)
            }
        } else if let err = state.lastError {
            Text(err)
                .font(Tokens.monoSmall)
                .foregroundStyle(.red.opacity(0.8))
                .lineLimit(2)
        } else {
            Text("polling…")
                .font(Tokens.monoSmall)
                .foregroundStyle(model.theme.dimText)
        }
    }

    private func netRow(_ snap: MetricsSnapshot) -> some View {
        let primary = snap.net.first
        return HStack(spacing: 14) {
            Label(formatRate(primary?.rxBps ?? 0), systemImage: "arrow.down")
                .font(Tokens.monoSmall)
                .foregroundStyle(model.theme.brightText)
            Label(formatRate(primary?.txBps ?? 0), systemImage: "arrow.up")
                .font(Tokens.monoSmall)
                .foregroundStyle(model.theme.brightText)
            Spacer()
            if let primary {
                Text(primary.name)
                    .font(Tokens.monoSmall)
                    .foregroundStyle(model.theme.dimText)
            }
        }
    }

    private var statusDot: some View {
        let online = device.isOnline
        let withAgent = device.hasAgent && state.lastError == nil && state.latest != nil
        let color: Color = !online ? .gray
            : (withAgent ? model.theme.accent : .yellow)
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .shadow(color: color.opacity(0.7), radius: 4)
    }

    private func osSymbol(for os: String) -> String {
        switch os.lowercased() {
        case let s where s.contains("darwin") || s.contains("macos"): return "apple.logo"
        case let s where s.contains("linux"):  return "terminal"
        case let s where s.contains("windows"): return "pc"
        default: return "questionmark.square.dashed"
        }
    }

    private func percent(_ v: Double) -> String {
        String(format: "%.1f%%", v)
    }

    private func formatRate(_ bps: UInt64) -> String {
        let units: [(UInt64, String)] = [
            (1_000_000_000, "GB/s"),
            (1_000_000,     "MB/s"),
            (1_000,         "KB/s"),
        ]
        for (scale, unit) in units where bps >= scale {
            return String(format: "%.1f %@", Double(bps) / Double(scale), unit)
        }
        return "\(bps) B/s"
    }
}

private struct Bar: View {
    @Environment(DashboardModel.self) private var model
    let label: String
    /// Fill fraction in 0...1.
    let value: Double
    let trailing: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(Tokens.monoSmall)
                    .foregroundStyle(model.theme.dimText)
                Spacer()
                Text(trailing)
                    .font(Tokens.monoSmall)
                    .foregroundStyle(model.theme.brightText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(model.theme.accent.opacity(0.15))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(model.theme.accent)
                        .frame(width: max(0, min(1, value)) * geo.size.width)
                }
            }
            .frame(height: 4)
        }
    }
}
