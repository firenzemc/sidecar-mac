# sidecar-agent

Cross-platform metrics agent for Sidecar. Single Go binary; runs on every
device in the tailnet you want to monitor.

See [../docs/protocol.md](../docs/protocol.md) for the JSON contract and
[../docs/architecture.md](../docs/architecture.md) for design background.

## Build

Local build for the current platform:

```sh
go build ./cmd/sidecar-agent
```

Cross-compile all four targets:

```sh
for tuple in linux/amd64 darwin/arm64 darwin/amd64 windows/amd64; do
  GOOS=${tuple%/*} GOARCH=${tuple#*/} CGO_ENABLED=0 \
    go build -ldflags="-s -w -X main.Version=0.1.0" \
    -o "bin/sidecar-agent-${tuple%/*}-${tuple#*/}" ./cmd/sidecar-agent
done
```

CGO is not required; binaries are statically linked.

## Run

By default the agent auto-detects the host's Tailscale interface (any
interface with an IP in `100.64.0.0/10` or `fd7a:115c:a1e0::/48`) and binds
**only** to those addresses on port 8765:

```sh
./sidecar-agent
```

For local development without Tailscale, override with `--bind`:

```sh
./sidecar-agent --bind 127.0.0.1 --port 18765
```

Flags:

| Flag           | Default | Notes                                                    |
| -------------- | ------- | -------------------------------------------------------- |
| `--port`       | `8765`  | TCP port for each Tailscale address                      |
| `--bind`       | *(auto)*| Comma-separated `host` or `host:port` overrides          |
| `--sample`     | `1s`    | Metrics sampling interval                                |
| `--print-bind` | `false` | Print the addresses that would be bound and exit         |

## Endpoints

| Path        | Returns                                          |
| ----------- | ------------------------------------------------ |
| `/healthz`  | `200 ok` plain text                              |
| `/info`     | Static host / agent / tailnet info (JSON)        |
| `/metrics`  | Latest snapshot (JSON, see protocol.md)          |

All responses include `X-Sidecar-Agent: v0.1` (protocol version).

## Tailscale interface detection

The agent identifies the Tailscale interface by **IP range**, not by name —
so it works whether the OS named it `tailscale0` (Linux), `utun*` (older
macOS), or `Tailscale` (Windows). If your Tailscale node has an IP in the
CGNAT range, the agent will find it.

## Security

- The agent never binds to `0.0.0.0`. It refuses to start if the only
  available addresses are non-Tailscale ones (use `--bind` explicitly to
  opt out).
- All endpoints are read-only `GET`. There is no application-layer auth in
  v0; tailnet ACLs are the trust boundary.
