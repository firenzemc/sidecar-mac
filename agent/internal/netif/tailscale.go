package netif

import (
	"fmt"
	"net"
	"net/netip"
	"strings"
)

var (
	cgnatPrefix = netip.MustParsePrefix("100.64.0.0/10")
	tsv6Prefix  = netip.MustParsePrefix("fd7a:115c:a1e0::/48")
)

type TailscaleAddrs struct {
	Interface string
	IPv4      netip.Addr
	IPv6      netip.Addr
}

// Detect scans system interfaces for Tailscale addresses.
// It identifies Tailscale by IP range (CGNAT 100.64/10 for v4, fd7a:115c:a1e0::/48 for v6),
// which works regardless of interface name (tailscale0, utun*, "Tailscale" on Win).
func Detect() (*TailscaleAddrs, error) {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil, fmt.Errorf("list interfaces: %w", err)
	}
	for _, ifi := range ifaces {
		if ifi.Flags&net.FlagUp == 0 {
			continue
		}
		addrs, err := ifi.Addrs()
		if err != nil {
			continue
		}
		var v4, v6 netip.Addr
		for _, a := range addrs {
			ipNet, ok := a.(*net.IPNet)
			if !ok {
				continue
			}
			ip, ok := netip.AddrFromSlice(ipNet.IP)
			if !ok {
				continue
			}
			ip = ip.Unmap()
			switch {
			case ip.Is4() && cgnatPrefix.Contains(ip):
				v4 = ip
			case ip.Is6() && tsv6Prefix.Contains(ip):
				v6 = ip
			}
		}
		if v4.IsValid() || v6.IsValid() {
			return &TailscaleAddrs{Interface: ifi.Name, IPv4: v4, IPv6: v6}, nil
		}
	}
	return nil, fmt.Errorf("no Tailscale interface found (looked for IPs in %s and %s)", cgnatPrefix, tsv6Prefix)
}

// BindAddrs renders host:port strings for net.Listen.
// IPv6 addresses are wrapped in brackets per RFC 3986.
func (t *TailscaleAddrs) BindAddrs(port int) []string {
	var out []string
	if t.IPv4.IsValid() {
		out = append(out, fmt.Sprintf("%s:%d", t.IPv4.String(), port))
	}
	if t.IPv6.IsValid() {
		out = append(out, fmt.Sprintf("[%s]:%d", t.IPv6.String(), port))
	}
	return out
}

func (t *TailscaleAddrs) Summary() string {
	var parts []string
	if t.IPv4.IsValid() {
		parts = append(parts, t.IPv4.String())
	}
	if t.IPv6.IsValid() {
		parts = append(parts, t.IPv6.String())
	}
	return fmt.Sprintf("%s (%s)", t.Interface, strings.Join(parts, ", "))
}
