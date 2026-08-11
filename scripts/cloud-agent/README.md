# 用 Python 驱动 Cursor Cloud Agent

从命令行/脚本/CI 里创建并运行 Cloud Agent，跑在 Cursor 托管的 VM 上，
并可挂载服务器的 `server-files` MCP 直接读写 `/workspace`。

这是官方通道（`cursor-sdk`，底层是 `/v1/agents` REST API），不是网页抓取。

## 环境

需要 Python 3.10+（本机用 3.14）。

```powershell
py -3.14 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

## 两个密钥

| 变量 | 从哪来 | 作用 |
|---|---|---|
| `CURSOR_API_KEY` | [Dashboard → Integrations](https://cursor.com/dashboard/integrations) | 调用 Cloud Agent |
| `MCP_KEY` | 服务器上签发的对外 key | 让 Cloud Agent 访问 `/workspace`（可省略） |

```powershell
$env:CURSOR_API_KEY = "cursor_xxx"
$env:MCP_KEY = "mcp-ext-xxx"
```

## 用法

```powershell
.\.venv\Scripts\python.exe run_cloud_agent.py "列出 /workspace 目录并总结这个项目"
```

常用参数：

```
--repo   仓库地址（默认 gbd-config）
--ref    起始分支（默认 main）
--model  默认 composer-2.5
--pr     跑完自动开 PR
--no-mcp 不挂载 server-files
```

## 退出码

| 码 | 含义 |
|---|---|
| 0 | 跑完且成功 |
| 1 | 没启动起来（认证/配置/网络） |
| 2 | 启动了但执行失败 |

这两类失败要分开处理：1 是环境问题，修好重试；2 是任务本身失败，去看 transcript。

## 注意

- `cloud` 参数必须显式传，否则 SDK 会**静默**跑成本地 agent。
- MCP 的 `headers` 由 Cursor 后端注入，不会下发到云端 VM。
- 恢复已有 agent 时 MCP 配置不会保留，需要重新传。
