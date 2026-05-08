import SwiftUI

struct GridOverview: View {
    @Environment(DashboardModel.self) private var model

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: Tokens.gridSpacing)
    ]

    var body: some View {
        ZStack {
            if model.theme.showsGridBackdrop {
                GridBackdrop(color: model.theme.accent.opacity(0.06))
                    .ignoresSafeArea()
            }
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.devices.isEmpty {
            EmptyStateView()
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Tokens.gridSpacing) {
                    ForEach(model.devices) { device in
                        DeviceCard(
                            device: device,
                            state: model.states[device.id] ?? .empty
                        )
                    }
                }
                .padding(Tokens.gridSpacing)
            }
        }
    }
}

private struct EmptyStateView: View {
    @Environment(DashboardModel.self) private var model

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(model.theme.dimText)
            if let err = model.lastDiscoveryError {
                Text("discovery error")
                    .font(Tokens.monoDigits)
                    .foregroundStyle(model.theme.brightText)
                Text(err)
                    .font(Tokens.monoSmall)
                    .foregroundStyle(model.theme.dimText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("no peers discovered")
                    .font(Tokens.monoDigits)
                    .foregroundStyle(model.theme.brightText)
                Text("ensure tailscale CLI is installed and you're signed in")
                    .font(Tokens.monoSmall)
                    .foregroundStyle(model.theme.dimText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Subtle dotted-grid backdrop. Cheap to draw via Canvas.
private struct GridBackdrop: View {
    let color: Color
    var spacing: CGFloat = 24

    var body: some View {
        Canvas { ctx, size in
            let dot: CGFloat = 1.5
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: dot, height: dot)
                    ctx.fill(Path(ellipseIn: rect), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}
