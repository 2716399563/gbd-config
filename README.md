# gbd-config

Cursor Cloud Agent 通过**服务器**上的 MCP + Cloudflare Tunnel 读写工作区文件；Windows 本机用 Git 同步。

## 架构

```
Windows (Git pull/push)  ←→  GitHub  ←→  Cursor Cloud Agent
                              ↕
                         你的 Linux 服务器
                    (MCP 文件服务 + cloudflared)
                              ↕
                    Cloudflare Tunnel + Access
                              ↕
                    Cloud Agent 通过 MCP 改服务器上的文件
```

**你不需要在 Windows 上跑隧道。** 服务器完成：MCP 网关、Cloudflare connector、托管仓库工作副本。

## 快速开始（服务器）

### 1. 准备 Cloudflare

1. [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) → **Networks** → **Tunnels** → 创建 Tunnel。
2. 添加 Public Hostname，例如 `mcp.yourdomain.com`：
   - Service type: **HTTP**
   - URL: `http://mcp-gateway:8000`（Docker 网络内服务名，见 `docker-compose.yml`）
3. **Access** → **Applications** → 为该 hostname 创建 Self-hosted 应用。
4. **Access** → **Service Auth** → 创建 **Service Token**，记下 Client ID 和 Secret。

### 2. 在服务器部署

```bash
git clone https://github.com/2716399563/gbd-config.git
cd gbd-config
cp scripts/server/.env.example scripts/server/.env
# 编辑 .env：填入 CLOUDFLARED_TUNNEL_TOKEN、WORKSPACE_PATH
chmod +x scripts/server/setup.sh
./scripts/server/setup.sh
```

### 3. 配置 Cursor Cloud Agent

在 [Cloud Agents Dashboard](https://cursor.com/dashboard/cloud-agents)：

| 类型 | 名称 | 值 |
|------|------|-----|
| Runtime Secret | `CF_ACCESS_CLIENT_ID` | Cloudflare Access Service Token ID |
| Runtime Secret | `CF_ACCESS_CLIENT_SECRET` | Cloudflare Access Service Token Secret |
| Environment Variable | `MCP_SERVER_URL` | `https://mcp.yourdomain.com/mcp` |

若启用了 egress 限制，把 `mcp.yourdomain.com` 加入 **network allowlist**。

编辑 `.cursor/mcp.json`，将 `url` 改为你的真实 MCP 地址（与 `MCP_SERVER_URL` 一致）。

### 4. Windows 同步

```powershell
cd C:\path\to\gbd-config
.\scripts\windows\sync.ps1
```

Cloud Agent 通过 MCP 改的是**服务器磁盘**上的仓库。Windows 用 `sync.ps1` 从 GitHub 拉取（若 Agent 同时 push 了 PR/commit），或配置服务器 Git remote 后从服务器拉。

## Subagent

| 文件 | 模型 | 用途 |
|------|------|------|
| `.cursor/agents/server-executor.md` | `claude-fable-5-thinking-xhigh` | 委派模式下的执行子代理 |
| `.cursor/agents/local-editor.md` | `claude-opus-5-thinking-high` | 通过 MCP 编辑服务器工作区文件 |

启动 Cloud Agent 时可说：「用 server-executor 子代理，通过 MCP 修改服务器上的配置文件」。

## 安全

- MCP 仅暴露 `WORKSPACE_PATH` 目录（filesystem server 参数限制）。
- 必须启用 Cloudflare Access Service Token。
- 定期轮换 Tunnel Token 与 Access Token。
- 不要把 token 提交到 Git。

## 目录

```
scripts/server/     服务器 Docker 部署（MCP + cloudflared）
scripts/windows/    Windows Git 同步脚本
.cursor/agents/     Subagent 定义
.cursor/mcp.json    Cloud Agent MCP 配置
.cursor/environment.json  Cloud 环境配置
```
