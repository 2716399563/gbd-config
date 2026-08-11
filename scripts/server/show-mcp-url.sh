#!/usr/bin/env bash
# 在服务器上执行：根据 quick tunnel 日志更新说明
set -euo pipefail
URL="$(docker logs gbd-cloudflared-quick 2>&1 | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | head -1)"
if [[ -z "${URL}" ]]; then
  echo "未找到 trycloudflare URL。容器是否在运行？"
  docker ps --filter name=gbd-
  exit 1
fi
echo "MCP URL（填入 .cursor/mcp.json）:"
echo "  ${URL}/mcp"
echo ""
echo "测试本地 MCP 网关:"
curl -s -o /dev/null -w "localhost mcp-gateway: %{http_code}\n" http://127.0.0.1:8000/mcp || true
