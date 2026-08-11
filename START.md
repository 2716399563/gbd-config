## 让我帮你完成（GitHub Actions）

若不想在 Cursor 填 Secret，可在 **GitHub 仓库 Settings → Secrets and variables → Actions** 添加：

| Secret | 值 |
|--------|-----|
| `SSH_PRIVATE_KEY` | huangshibo.pem **全文** |
| `SERVER_HOST` | `20.255.73.137`（可选，有默认值） |
| `SSH_USER` | `azureuser`（可选） |

然后：**Actions** → **Deploy MCP stack to Azure** → **Run workflow**。

或告诉我「Secrets 已填到 GitHub」，我会触发 workflow。

## 按推荐路径部署（约 5 分钟）

服务器：`20.255.73.137`（Azure Ubuntu 22.04）

## 第 1 步：Azure 门户启动 MCP + 隧道（不用把 PEM 给我）

1. 打开 [Azure 门户](https://portal.azure.com) → 虚拟机 → **运行命令**
2. 选择 **RunShellScript**
3. 粘贴下面整段，点 **运行**：

```bash
curl -fsSL https://raw.githubusercontent.com/2716399563/gbd-config/cursor/cloudflare-mcp-setup-fc43/scripts/server/azure-bootstrap.sh | bash
```

4. 在输出里找到类似：

```
https://xxxxxxxx.trycloudflare.com
```

记下完整 MCP 地址：`https://xxxxxxxx.trycloudflare.com/mcp`

## 第 2 步：Windows 上传 amd-radeon-register 到服务器

PowerShell：

```powershell
git clone -b cursor/cloudflare-mcp-setup-fc43 https://github.com/2716399563/gbd-config.git C:\dev\gbd-config
cd C:\dev\gbd-config
.\scripts\windows\upload-and-deploy.ps1
```

（已默认 IP、azureuser、你的 PEM 和项目路径）

## 第 3 步：把 MCP 地址告诉 Cursor

把第 1 步的 URL 发给我，或自行改仓库 `.cursor/mcp.json`：

```json
"url": "https://你的子域.trycloudflare.com/mcp"
```

然后新开 Cloud Agent，说：「用 server-executor 通过 MCP 读取 /workspace 下的文件」。

## 可选：让我远程代劳

Cursor → Cloud Agents → Secrets：

- `SSH_PRIVATE_KEY` = huangshibo.pem 全文
- `SSH_USER` = azureuser

填好后回复「Secrets 已填」，我 SSH 完成第 1、2 步。
