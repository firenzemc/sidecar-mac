package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/firenzemc/sidecar-mac/agent/internal/collector"
	"github.com/firenzemc/sidecar-mac/agent/internal/netif"
	"github.com/firenzemc/sidecar-mac/agent/internal/server"
)

// Version is the agent's semver string. Override with -ldflags="-X main.Version=...".
var Version = "0.1.0-dev"

func main() {
	var (
		port      = flag.Int("port", 8765, "TCP port to bind on each Tailscale address")
		bind      = flag.String("bind", "", "comma-separated host:port overrides (skips Tailscale auto-detect)")
		sample    = flag.Duration("sample", time.Second, "metrics sampling interval")
		printOnly = flag.Bool("print-bind", false, "print bind addresses and exit")
	)
	flag.Parse()

	addrs, err := resolveBindAddrs(*bind, *port)
	if err != nil {
		log.Fatalf("bind: %v", err)
	}

	if *printOnly {
		for _, a := range addrs {
			fmt.Println(a)
		}
		return
	}

	ts, _ := netif.Detect() // best-effort, may be nil if --bind override is used

	col := collector.New(*sample)

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	go col.Run(ctx)

	srv := server.New(Version, col, ts)
	log.Printf("sidecar-agent %s starting; bind=%v", Version, addrs)
	if err := srv.ListenAndServe(ctx, addrs); err != nil {
		log.Fatalf("server: %v", err)
	}
	log.Printf("sidecar-agent stopped")
}

// resolveBindAddrs returns the list of host:port to listen on. Either:
//   - explicit --bind override: comma-separated list, each entry is "host" or "host:port".
//     Bare hosts use the global --port.
//   - auto-detected Tailscale addresses (CGNAT v4 and Tailscale ULA v6 on a single interface).
func resolveBindAddrs(override string, port int) ([]string, error) {
	if override != "" {
		var out []string
		for _, raw := range strings.Split(override, ",") {
			a := strings.TrimSpace(raw)
			if a == "" {
				continue
			}
			if !strings.Contains(a, ":") || (strings.HasPrefix(a, "[") && strings.HasSuffix(a, "]")) {
				a = fmt.Sprintf("%s:%d", a, port)
			}
			out = append(out, a)
		}
		if len(out) == 0 {
			return nil, fmt.Errorf("--bind was set but produced no addresses")
		}
		return out, nil
	}

	ts, err := netif.Detect()
	if err != nil {
		return nil, fmt.Errorf("auto-detect Tailscale interface: %w (use --bind to override)", err)
	}
	addrs := ts.BindAddrs(port)
	log.Printf("detected Tailscale interface: %s", ts.Summary())
	return addrs, nil
}
