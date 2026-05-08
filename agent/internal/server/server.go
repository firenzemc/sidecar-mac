package server

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/firenzemc/sidecar-mac/agent/internal/collector"
	"github.com/firenzemc/sidecar-mac/agent/internal/netif"
	"github.com/shirou/gopsutil/v3/host"
)

const (
	headerAgentVersion = "X-Sidecar-Agent"
	protocolVersion    = "v0.1"
)

type Server struct {
	version   string
	startedAt time.Time
	col       *collector.Collector
	ts        *netif.TailscaleAddrs
}

func New(version string, col *collector.Collector, ts *netif.TailscaleAddrs) *Server {
	return &Server{
		version:   version,
		startedAt: time.Now().UTC(),
		col:       col,
		ts:        ts,
	}
}

func (s *Server) routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/info", s.handleInfo)
	mux.HandleFunc("/metrics", s.handleMetrics)
	return mux
}

// ListenAndServe binds the agent's HTTP server to every address in addrs and
// blocks until ctx is cancelled or any listener fails.
func (s *Server) ListenAndServe(ctx context.Context, addrs []string) error {
	if len(addrs) == 0 {
		return errors.New("no bind addresses")
	}
	mux := s.routes()
	wrapped := withVersionHeader(mux, s.version)

	var wg sync.WaitGroup
	errCh := make(chan error, len(addrs))
	servers := make([]*http.Server, 0, len(addrs))

	for _, addr := range addrs {
		ln, err := net.Listen("tcp", addr)
		if err != nil {
			for _, srv := range servers {
				_ = srv.Close()
			}
			return fmt.Errorf("listen %s: %w", addr, err)
		}
		srv := &http.Server{
			Handler:           wrapped,
			ReadHeaderTimeout: 5 * time.Second,
		}
		servers = append(servers, srv)
		wg.Add(1)
		go func(addr string) {
			defer wg.Done()
			log.Printf("listening on %s", addr)
			if err := srv.Serve(ln); err != nil && !errors.Is(err, http.ErrServerClosed) {
				errCh <- fmt.Errorf("serve %s: %w", addr, err)
			}
		}(addr)
	}

	select {
	case <-ctx.Done():
	case err := <-errCh:
		for _, srv := range servers {
			_ = srv.Close()
		}
		wg.Wait()
		return err
	}

	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	for _, srv := range servers {
		_ = srv.Shutdown(shutCtx)
	}
	wg.Wait()
	return nil
}

func withVersionHeader(h http.Handler, _ string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set(headerAgentVersion, protocolVersion)
		h.ServeHTTP(w, r)
	})
}

func (s *Server) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = w.Write([]byte("ok\n"))
}

func (s *Server) handleInfo(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	platform, _, version, _ := host.PlatformInformationWithContext(r.Context())
	kernel, _ := host.KernelVersionWithContext(r.Context())
	platformStr := platform
	if version != "" {
		platformStr = strings.TrimSpace(platform + " " + version)
	}
	if platformStr == "" {
		platformStr = runtime.GOOS
	}

	tn := collector.Tailnet{}
	if s.ts != nil {
		if s.ts.IPv4.IsValid() {
			tn.TailscaleIP4 = s.ts.IPv4.String()
		}
		if s.ts.IPv6.IsValid() {
			tn.TailscaleIP6 = s.ts.IPv6.String()
		}
	}
	tn.MagicDNSName = lookupMagicDNS(r.Context())

	info := collector.Info{
		Agent: collector.AgentInfo{
			Version:   s.version,
			StartedAt: s.startedAt,
		},
		Host: collector.HostInfo{
			Hostname: hostname,
			OS:       runtime.GOOS,
			Arch:     runtime.GOARCH,
			Kernel:   kernel,
			Platform: platformStr,
		},
		Tailnet:      tn,
		Capabilities: capabilities(),
	}
	writeJSON(w, http.StatusOK, info)
}

func (s *Server) handleMetrics(w http.ResponseWriter, _ *http.Request) {
	snap := s.col.Latest()
	if snap == nil {
		writeError(w, http.StatusServiceUnavailable, "transient", "first sample not ready")
		return
	}
	writeJSON(w, http.StatusOK, snap)
}

func capabilities() []string {
	caps := []string{"metrics.cpu", "metrics.mem", "metrics.disk", "metrics.net"}
	if runtime.GOOS != "windows" {
		caps = append(caps, "metrics.load")
	}
	return caps
}

// lookupMagicDNS shells out to `tailscale status --json` to discover the MagicDNS
// name. Returns "" if the CLI isn't available; agent must keep working without it.
func lookupMagicDNS(ctx context.Context) string {
	tsCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	out, err := exec.CommandContext(tsCtx, "tailscale", "status", "--json").Output()
	if err != nil {
		return ""
	}
	var status struct {
		Self struct {
			DNSName string `json:"DNSName"`
		} `json:"Self"`
	}
	if err := json.Unmarshal(out, &status); err != nil {
		return ""
	}
	return strings.TrimSuffix(status.Self.DNSName, ".")
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(v); err != nil {
		log.Printf("encode response: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, code, msg string) {
	writeJSON(w, status, map[string]any{
		"error": map[string]string{"code": code, "message": msg},
	})
}
