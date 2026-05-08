# sidecar-mac

SwiftUI dashboard for [sidecar-agent](../agent). macOS 14+, no third-party
runtime dependencies.

> Status: **M2** — main app skeleton with peer discovery, polling, mock mode,
> and a grid of device cards. WidgetKit extension lands in M3.

## Bootstrap (one-time on Mac)

The `.xcodeproj` is **not** committed; it's generated from `project.yml` via
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
cd macapp
xcodegen generate
open Sidecar.xcodeproj
```

Build & run from Xcode (`⌘R`).

## How it discovers devices

1. Shells out to `tailscale status --json` (looks for the binary in
   `/usr/local/bin`, `/opt/homebrew/bin`, and inside `Tailscale.app`).
2. For each peer, probes `http://<MagicDNSName>:8765/healthz` in parallel.
3. Peers that answer 200 get a CARD with live metrics; peers without an
   agent stay visible with a "no agent" badge.

Discovery refreshes every 30 s; metrics poll every 5 s. Both are configurable
on the model (`pollInterval`, `discoveryInterval`).

## Mock mode

The toolbar `Live | Mock` toggle flips to a deterministic mock dataset (5
devices, drifting metrics). Useful when designing the UI without an active
tailnet — and as a safety net if discovery fails.

## Sandbox

App Sandbox is **disabled** in `Sidecar.entitlements` because we shell out to
the `tailscale` binary. Re-enabling sandbox would require either:

- talking to Tailscale's LocalAPI socket directly (and shipping a helper), or
- a privileged helper tool installed via `SMAppService`.

Both are tracked for a later milestone; for v0 the unsandboxed app is
acceptable since distribution is direct (not Mac App Store).

## Project layout

```
macapp/
├── project.yml                  XcodeGen config (source of truth)
├── Sidecar/
│   ├── SidecarApp.swift         @main, WindowGroup
│   ├── ContentView.swift        toolbar + GridOverview host
│   ├── Info.plist
│   ├── Sidecar.entitlements
│   ├── Models/
│   │   ├── Device.swift         Device + DeviceState
│   │   └── AgentDTO.swift       Codable types matching docs/protocol.md
│   ├── Services/
│   │   ├── TailscaleCLI.swift   Process wrapper + status JSON decode
│   │   ├── AgentClient.swift    URLSession wrapper for /info /metrics
│   │   ├── PeerDiscovery.swift  status + parallel /healthz probe
│   │   ├── Poller.swift         actor; periodic /metrics fetch
│   │   └── MockData.swift       deterministic mock devices + snapshots
│   ├── ViewModel/
│   │   └── DashboardModel.swift @Observable; the screen's source of truth
│   ├── Views/
│   │   ├── GridOverview.swift   LazyVGrid + dotted-grid backdrop
│   │   └── DeviceCard.swift     hostname / OS / CPU / MEM / NET
│   └── Theme/
│       └── Theme.swift          Grid / Phosphor / Glass + design tokens
```
