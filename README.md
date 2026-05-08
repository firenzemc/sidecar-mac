# Sidecar

一个面向 Tailscale 网络的轻量级设备监控 dashboard，原生 macOS 形态，桌面 widget 优先。

## 起源

我有好几台设备同时挂在 Tailscale 网络里 —— Win、Mac、Linux 都有，我希望能在主力 Mac 上有一个常驻的面板，持续看到这些设备的基础状态（在线/离线、CPU/内存/流量等），必要时可以展开看详情。

我没找到特别趁手的现成方案 —— 要么太重（Grafana 全家桶），要么只看在线状态没看系统指标，要么不是 macOS 原生形态。所以做这个：

- **形态贴合 macOS** — 桌面 widget 驻留，可选 menu bar，主 app 用于详情展开
- **科技美学** — 暗色为主、等宽数字、网格背景、细发光描边，多个 theme 可切换
- **多视图** — 设备网格概览 / 单设备详情卡片 / widget 时间线

## 架构总览

```
┌─────────────────────┐         tailnet (MagicDNS)        ┌───────────────────────┐
│   sidecar-agent     │                                   │     sidecar-mac       │
│   (Win/Mac/Linux)   │ ─── HTTP /info /metrics ────────► │   SwiftUI + WidgetKit │
│                     │                                   │                       │
│  - 采集 CPU/Mem     │                                   │  - 设备网格           │
│  - 采集 Disk/Net    │                                   │  - 详情卡片           │
│  - 暴露 :8765       │                                   │  - 桌面 widgets       │
└─────────────────────┘                                   └───────────────────────┘
        ▲                                                            │
        │                                                            │
        └────────── 都通过 tailscaled 加入 tailnet ──────────────────┘
```

- agent 是一个 Go 写的单二进制，跨平台编译，依赖宿主机已经装好的 Tailscale 客户端（tailscaled），
  只在 `tailscale0` 接口监听固定端口，不暴露公网。
- mac app 通过本地 `tailscale status --json` 列出 peer，按约定端口探测，发现 agent 后开始轮询。
- widget 通过 App Group 共享容器读 mac app 写下的最新快照。

## 仓库结构

```
sidecar-mac/
├── agent/                     Go 写的跨平台采集 agent（单二进制）
├── macapp/                    Xcode 工程：主 app + widget extension
├── docs/
│   ├── architecture.md        架构与设计细节
│   └── protocol.md            agent <-> app 的 JSON 协议草案
└── README.md
```

## 当前状态

仓库刚起步，目前只有架构与协议文档。下一步按 milestone 推进。

## Roadmap

- **M0 — 文档与协议** *(当前)*
  - [x] README / 架构 / 协议草案
- **M1 — agent 最小可用**
  - [ ] Go 项目骨架 + gopsutil 采集
  - [ ] HTTP server 绑 tailscale0 监听 :8765
  - [ ] `/info`、`/metrics`、`/healthz` 三个端点
  - [ ] Win / Mac / Linux 交叉编译
- **M2 — Mac 主 app 骨架**
  - [ ] SwiftUI 工程 + 主窗口
  - [ ] PeerDiscovery：解析 `tailscale status --json` + 端口探测
  - [ ] Poller：定时抓 `/metrics`
  - [ ] 设备网格视图（mock + 真实数据切换）
- **M3 — Widget extension**
  - [ ] App Group 共享容器
  - [ ] Small / Medium / Large 三档 widget
  - [ ] TimelineProvider 节流（5–15 分钟）
- **M4 — 视觉与 theme**
  - [ ] 主题系统（暗色 + 2–3 个 accent）
  - [ ] 单设备详情卡（迷你火花线 / 流量图）
- **M5 — 打包与分发**
  - [ ] agent installer / launchd / systemd / Windows service
  - [ ] mac app 签名与公证

## 非目标

- 不做 alerting / 通知中心（先把"看"做好）
- 不做长周期历史存储（短窗口环形缓冲即可，长历史去用 Grafana）
- 不做 Tailscale 控制平面管理（不接管 ACL / device approval）
- 不做 Win / Linux 端的 dashboard（其它平台只跑 agent）

## 文档

- [架构与设计](docs/architecture.md)
- [agent 协议草案](docs/protocol.md)
