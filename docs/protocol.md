# agent ↔ app 协议草案 (v0)

agent 暴露 HTTP，JSON over `application/json`，UTF-8。
所有时间戳为 RFC 3339（含时区）。所有字节为 base-10（非二进制单位）。

> **版本协商** — 响应头 `X-Sidecar-Agent: v0.<minor>`。client 见到 major 不一致直接降级到只显示 `/info`。

## `GET /healthz`

存活探测，body 任意（实现上返回 `ok\n`）。

```
HTTP/1.1 200 OK
Content-Type: text/plain
```

## `GET /info`

启动期间不变的静态信息。client 在发现阶段调用一次，缓存。

```json
{
  "agent": {
    "version": "0.1.0",
    "started_at": "2026-05-08T03:14:15Z"
  },
  "host": {
    "hostname": "hayabusa",
    "os": "darwin",
    "arch": "arm64",
    "kernel": "24.4.0",
    "platform": "macOS 15.4"
  },
  "tailnet": {
    "tailscale_ip4": "100.64.1.23",
    "tailscale_ip6": "fd7a:115c:a1e0::1",
    "magicdns_name": "hayabusa.tailnet-xxxx.ts.net"
  },
  "capabilities": ["metrics.cpu", "metrics.mem", "metrics.disk", "metrics.net", "metrics.load"]
}
```

字段说明：

- `agent.version` — semver
- `host.os` — Go 风格：`darwin` / `linux` / `windows`
- `capabilities` — 该 agent 实际暴露的指标族；client 据此决定渲染哪些卡片

## `GET /metrics`

当前快照。agent 内部以 1 秒滚动采样，本端点直接返回最近一帧（不阻塞采样）。

```json
{
  "ts": "2026-05-08T03:15:42.812Z",
  "uptime_seconds": 184213,
  "cpu": {
    "usage_percent": 12.4,
    "cores": 10
  },
  "mem": {
    "used_bytes": 12884901888,
    "total_bytes": 34359738368,
    "swap_used_bytes": 0,
    "swap_total_bytes": 0
  },
  "load": {
    "load1": 1.42,
    "load5": 1.18,
    "load15": 0.95
  },
  "disks": [
    {
      "mount": "/",
      "fstype": "apfs",
      "used_bytes": 412316860416,
      "total_bytes": 994662584320
    }
  ],
  "net": [
    {
      "name": "en0",
      "rx_bps": 1248391,
      "tx_bps": 384712,
      "rx_total_bytes": 9183746234,
      "tx_total_bytes": 1827364512
    }
  ]
}
```

可空字段：

- `load` 整体为 `null`（Windows 没有 loadavg）
- `mem.swap_*` 为 `null`（不支持的平台）
- `disks` / `net` 可为空数组

字段约定：

- `*_bps` —— 与上一帧的差分 / 时间间隔，floor 不为负
- `usage_percent` —— `[0, 100]`，整机平均
- `total_bytes >= used_bytes` 始终成立

## `GET /metrics/stream` *(预留, v0 不实现)*

server-sent events，用于主 app 打开时的高频实时视图。v0 阶段 client 用 1–2 秒轮询替代。

## 错误响应

```json
{ "error": { "code": "internal", "message": "..." } }
```

`code` 取值：

- `internal` — 采集出错
- `not_supported` — 平台不支持该端点
- `transient` — 暂时性错误，client 应重试

## 兼容策略

- v0 → v1：新增字段不算 break；删除/语义变更必须 bump major。
- agent 见到未知 query 参数应忽略不报错。
- client 见到未知字段应忽略不报错（forward compatibility）。
