# 架构与设计

## 设计原则

1. **Tailnet 是信任边界** — agent 只监听 `tailscale0`，不暴露公网，认证依赖 ACL。
2. **Pull 优于 push** — mac 端轮询，简单、可缓存、widget timeline 好对齐。
3. **零配置发现** — 不维护 device 列表，靠 `tailscale status --json` + 端口探测。
4. **轻量优先** — agent 内存占用目标 < 30 MB，CPU 空闲 < 1%；不做长周期存储。
5. **Mac app 是唯一前端** — Win / Linux 端只跑 agent，不写跨平台 UI。

## agent

### 接入 tailnet

依赖宿主机已经在跑 `tailscaled`。agent 启动时：

1. 解析本机 `tailscale0` 的 IP（IPv4 / IPv6 各一个）。
2. HTTP server 只在这两个 IP + 固定端口 `:8765` 上监听，**不绑 0.0.0.0**。
3. 不做应用层鉴权（v1）；信任 tailnet ACL。后续可加 `Tailscale-Whois` 反查调用方身份。

> **为什么不用 tsnet？** —— 用户指定依赖宿主机 tailscaled。优点：每台机器一个身份，
> tailscale 控制台里 1:1 对应；缺点：必须先装 Tailscale 客户端。

### 采集器

用 [`gopsutil`](https://github.com/shirou/gopsutil) 跨平台采集：

| 指标             | 字段                                         | 备注                          |
| ---------------- | -------------------------------------------- | ----------------------------- |
| CPU 占用         | `cpu.usage_percent`（0–100，整机平均）       | 1 秒采样窗口                  |
| 内存             | `mem.used_bytes` / `mem.total_bytes`         | 物理内存                      |
| 磁盘             | 每个挂载点：`mount`, `used`, `total`         | 只列容量 ≥ 1 GiB 的           |
| 网络流量         | 每个 NIC：`rx_bps` / `tx_bps`                | 与上次采样的差分              |
| 系统负载         | `load.1` / `load.5` / `load.15`              | Win 上没有，留 null           |
| Uptime           | `uptime_seconds`                             |                               |
| 主机名 / OS / 架构 | `hostname` / `os` / `arch` / `kernel`      | 在 `/info` 里一次性返回       |

采集频率：默认每 1 秒滚动一次，HTTP 请求来时直接返回最近一帧。

### HTTP 端点

- `GET /healthz` — 200 OK，纯健康检查
- `GET /info` — 静态信息（hostname / os / arch / agent version / 启动时间）
- `GET /metrics` — 当前快照（JSON，详见 [protocol.md](protocol.md)）

### 部署形态

- **macOS** — `launchd` user agent
- **Linux** — `systemd` unit
- **Windows** — Windows Service（用 `kardianos/service` 之类）

## sidecar-mac

### 模块划分

```
Sidecar (主 app target)
├── Models/
│   ├── Device.swift          tailnet peer + 是否带 agent
│   ├── Snapshot.swift        /metrics 解码后的强类型
│   └── Theme.swift
├── Services/
│   ├── TailscaleCLI.swift    封装 `tailscale status --json`
│   ├── PeerDiscovery.swift   tailnet peer + agent 探活
│   ├── AgentClient.swift     /info /metrics HTTP client
│   ├── Poller.swift          每 N 秒拉一次，写入 store
│   └── SharedStore.swift     App Group 共享容器（widget 可读）
├── Views/
│   ├── GridOverview.swift    所有设备的网格
│   ├── DeviceCard.swift      详情卡片
│   ├── Sparkline.swift       迷你火花线（自绘 Path）
│   └── ThemePicker.swift
└── Theme/
    ├── Tokens.swift          颜色 / 字体 / 间距 token
    └── Themes/               几套 theme JSON
```

```
SidecarWidget (extension target)
├── Provider.swift            TimelineProvider（读 SharedStore）
├── SmallWidget.swift         单设备 1 项指标
├── MediumWidget.swift        4–6 设备状态条
└── LargeWidget.swift         网格 + 火花线
```

### 设备发现流程

1. 每隔 30 秒 `tailscale status --json`，得到 peer 列表
2. 每个 peer 并发探测 `http://<MagicDNSName>:8765/healthz`
3. 200 → 标记为 agent 设备，加入轮询队列
4. peer 离线或 5 次连续探测失败 → 标记为 offline，但保留卡片

### 主 app ↔ widget 数据通道

- App Group：`group.dev.sidecar.shared`
- 在共享容器里维护 SQLite（或 JSON 文件 + atomic write），结构：
  - `devices` 表：device_id, hostname, os, last_seen
  - `snapshots` 环形：device_id, ts, cpu, mem, rx, tx
- widget `TimelineProvider` 每 ~10 分钟刷新读最新 N 条

### 视觉方向

- **Theme: Grid（默认）** — 深灰底 + 网格背景 + 青色 accent + JetBrains Mono / SF Mono
- **Theme: Phosphor** — 近黑底 + 单一品红/绿色 accent，CRT 微光感
- **Theme: Glass** — macOS 原生 material + accent 描边，相对克制

公共 token：
- 数字一律等宽
- 状态发光：online 用 1px 内描边 + 软阴影
- 卡片圆角 12 / widget 圆角随系统

## 安全考量

- agent 不接受任何 mutation 请求（只读 GET）
- `/metrics` 不含敏感路径（不返回 `$HOME` 等）
- 不暴露 0.0.0.0 是硬性约束 —— bind 失败时直接拒绝启动并打印日志
- 后续若加可写端点，必须用 Tailscale `whois` 校验调用方 + 加白名单 tag
