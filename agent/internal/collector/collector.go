package collector

import (
	"context"
	"runtime"
	"sync/atomic"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/load"
	"github.com/shirou/gopsutil/v3/mem"
	gnet "github.com/shirou/gopsutil/v3/net"
)

const minDiskBytes = 1 << 30 // 1 GiB

type Collector struct {
	interval time.Duration
	latest   atomic.Pointer[Snapshot]
	prevNet  map[string]gnet.IOCountersStat
	prevTS   time.Time
}

func New(interval time.Duration) *Collector {
	if interval <= 0 {
		interval = time.Second
	}
	return &Collector{interval: interval}
}

func (c *Collector) Latest() *Snapshot {
	return c.latest.Load()
}

func (c *Collector) Run(ctx context.Context) {
	c.sampleOnce(ctx)
	t := time.NewTicker(c.interval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			c.sampleOnce(ctx)
		}
	}
}

func (c *Collector) sampleOnce(ctx context.Context) {
	now := time.Now().UTC()
	snap := &Snapshot{TS: now}

	if up, err := host.UptimeWithContext(ctx); err == nil {
		snap.UptimeSeconds = up
	}

	cpuPct, _ := cpu.PercentWithContext(ctx, 0, false)
	snap.CPU = CPU{Cores: runtime.NumCPU()}
	if len(cpuPct) > 0 {
		snap.CPU.UsagePercent = roundTo(cpuPct[0], 1)
	}

	if vm, err := mem.VirtualMemoryWithContext(ctx); err == nil {
		snap.Mem.UsedBytes = vm.Used
		snap.Mem.TotalBytes = vm.Total
	}
	if sm, err := mem.SwapMemoryWithContext(ctx); err == nil {
		used, total := sm.Used, sm.Total
		snap.Mem.SwapUsedBytes = &used
		snap.Mem.SwapTotalBytes = &total
	}

	if runtime.GOOS != "windows" {
		if l, err := load.AvgWithContext(ctx); err == nil {
			snap.Load = &Load{Load1: l.Load1, Load5: l.Load5, Load15: l.Load15}
		}
	}

	if parts, err := disk.PartitionsWithContext(ctx, false); err == nil {
		for _, p := range parts {
			usage, err := disk.UsageWithContext(ctx, p.Mountpoint)
			if err != nil || usage.Total < minDiskBytes {
				continue
			}
			snap.Disks = append(snap.Disks, Disk{
				Mount:      p.Mountpoint,
				FSType:     p.Fstype,
				UsedBytes:  usage.Used,
				TotalBytes: usage.Total,
			})
		}
	}

	if counters, err := gnet.IOCountersWithContext(ctx, true); err == nil {
		curMap := make(map[string]gnet.IOCountersStat, len(counters))
		for _, c := range counters {
			curMap[c.Name] = c
		}
		dt := now.Sub(c.prevTS).Seconds()
		for _, cur := range counters {
			if isVirtualNIC(cur.Name) {
				continue
			}
			n := NetIO{
				Name:         cur.Name,
				RxTotalBytes: cur.BytesRecv,
				TxTotalBytes: cur.BytesSent,
			}
			if prev, ok := c.prevNet[cur.Name]; ok && dt > 0 {
				n.RxBps = ratePerSec(cur.BytesRecv, prev.BytesRecv, dt)
				n.TxBps = ratePerSec(cur.BytesSent, prev.BytesSent, dt)
			}
			snap.Net = append(snap.Net, n)
		}
		c.prevNet = curMap
		c.prevTS = now
	}

	c.latest.Store(snap)
}

func ratePerSec(cur, prev uint64, dt float64) uint64 {
	if cur < prev || dt <= 0 {
		return 0
	}
	return uint64(float64(cur-prev) / dt)
}

func roundTo(v float64, decimals int) float64 {
	pow := 1.0
	for i := 0; i < decimals; i++ {
		pow *= 10
	}
	return float64(int64(v*pow+0.5)) / pow
}

func isVirtualNIC(name string) bool {
	switch name {
	case "lo", "lo0":
		return true
	}
	return false
}
