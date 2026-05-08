package collector

import "time"

type Snapshot struct {
	TS            time.Time `json:"ts"`
	UptimeSeconds uint64    `json:"uptime_seconds"`
	CPU           CPU       `json:"cpu"`
	Mem           Mem       `json:"mem"`
	Load          *Load     `json:"load"`
	Disks         []Disk    `json:"disks"`
	Net           []NetIO   `json:"net"`
}

type CPU struct {
	UsagePercent float64 `json:"usage_percent"`
	Cores        int     `json:"cores"`
}

type Mem struct {
	UsedBytes      uint64  `json:"used_bytes"`
	TotalBytes     uint64  `json:"total_bytes"`
	SwapUsedBytes  *uint64 `json:"swap_used_bytes"`
	SwapTotalBytes *uint64 `json:"swap_total_bytes"`
}

type Load struct {
	Load1  float64 `json:"load1"`
	Load5  float64 `json:"load5"`
	Load15 float64 `json:"load15"`
}

type Disk struct {
	Mount      string `json:"mount"`
	FSType     string `json:"fstype"`
	UsedBytes  uint64 `json:"used_bytes"`
	TotalBytes uint64 `json:"total_bytes"`
}

type NetIO struct {
	Name         string `json:"name"`
	RxBps        uint64 `json:"rx_bps"`
	TxBps        uint64 `json:"tx_bps"`
	RxTotalBytes uint64 `json:"rx_total_bytes"`
	TxTotalBytes uint64 `json:"tx_total_bytes"`
}

type Info struct {
	Agent        AgentInfo `json:"agent"`
	Host         HostInfo  `json:"host"`
	Tailnet      Tailnet   `json:"tailnet"`
	Capabilities []string  `json:"capabilities"`
}

type AgentInfo struct {
	Version   string    `json:"version"`
	StartedAt time.Time `json:"started_at"`
}

type HostInfo struct {
	Hostname string `json:"hostname"`
	OS       string `json:"os"`
	Arch     string `json:"arch"`
	Kernel   string `json:"kernel"`
	Platform string `json:"platform"`
}

type Tailnet struct {
	TailscaleIP4 string `json:"tailscale_ip4"`
	TailscaleIP6 string `json:"tailscale_ip6"`
	MagicDNSName string `json:"magicdns_name"`
}
