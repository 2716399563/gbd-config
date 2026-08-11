#!/usr/bin/env bash
# 重启后修复 MCP 网关：改用预装的 filesystem server，加资源上限，落到持久目录。
set -eu

DIR=/opt/gbd-mcp
sudo mkdir -p "$DIR"
sudo cp /tmp/docker-compose.yml "$DIR/docker-compose.yml"

# /tmp 重启会被清空，配置改放 /opt 持久化
sudo tee "$DIR/.env" >/dev/null <<'EOF'
WORKSPACE_PATH=/opt/amd-radeon-register
MCP_PORT=8001
CLOUDFLARED_TUNNEL_TOKEN=
EOF

# 已改用公网 nginx 反代，临时隧道不再需要，去掉以省资源
sudo docker rm -f gbd-cloudflared-quick 2>/dev/null || true
# 旧容器属于另一个 compose 工程，必须先删掉，否则重建会撞名字
sudo docker rm -f gbd-mcp-gateway 2>/dev/null || true
sudo docker network rm gbd-mcp-net 2>/dev/null || true

cd "$DIR"
sudo docker compose --env-file .env up -d mcp-gateway

echo "=== waiting health ==="
for i in $(seq 1 60); do
  st="$(sudo docker inspect gbd-mcp-gateway --format='{{.State.Health.Status}}' 2>/dev/null || echo none)"
  echo "health=$st"
  if [ "$st" = "healthy" ]; then break; fi
  sleep 5
done

echo "=== containers ==="
sudo docker ps --format '{{.Names}} {{.Status}}' || true

echo "=== local probe :8001 ==="
curl -sS -m 10 -o /dev/null -w "gw8001=%{http_code} %{time_total}s\n" \
  -X POST http://127.0.0.1:8001/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1.0"}}}' || true

echo "=== load ==="
uptime || true
free -m | head -2 || true
