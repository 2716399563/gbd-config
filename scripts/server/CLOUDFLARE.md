# Cloudflare Tunnel 配置说明（服务器 Docker 部署）

部署 `docker-compose.yml` 后，cloudflared 与 MCP 网关在同一 Docker 网络 `gbd-mcp-net` 内。

## Public Hostname 填写

在 Zero Trust → Tunnels → 你的 Tunnel → Public Hostname：

| 字段 | 值 |
|------|-----|
| Subdomain | `mcp`（或任意） |
| Domain | 你的域名 |
| Type | HTTP |
| URL | `mcp-gateway:8000` |

**不要**写 `127.0.0.1`：connector 在容器里，应使用 Compose **服务名** `mcp-gateway`。

客户端访问：`https://mcp.yourdomain.com/mcp`（Streamable HTTP）

## Cloudflare Access

1. Access → Applications → Add application → Self-hosted
2. Application domain：`mcp.yourdomain.com`
3. Policy：Service Auth → 允许你的 Service Token
4. 创建 Service Token，写入 Cursor Secrets：
   - `CF_ACCESS_CLIENT_ID`
   - `CF_ACCESS_CLIENT_SECRET`

## 验证

```bash
# 服务器上（需带 Access 头）
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "CF-Access-Client-Id: $CF_ACCESS_CLIENT_ID" \
  -H "CF-Access-Client-Secret: $CF_ACCESS_CLIENT_SECRET" \
  https://mcp.yourdomain.com/mcp
```

返回非 5xx 即连通（405/406 也可能表示服务在监听）。

## 轮换凭证

更换 Tunnel Token 或 Access Token 后：

1. 更新 `scripts/server/.env` 中的 `CLOUDFLARED_TUNNEL_TOKEN`
2. 更新 Cursor Dashboard Secrets
3. `docker compose --env-file .env up -d`
