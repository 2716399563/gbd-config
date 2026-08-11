#!/usr/bin/env bash
# 启用 MCP 的 HTTPS 入口，并在服务器本地验证
set -eu

DOMAIN="20-255-73-137.sslip.io"
MCP_KEY="${MCP_KEY:-REPLACE_WITH_YOUR_KEY}"

sudo cp /tmp/nginx-mcp-ssl.conf /etc/nginx/sites-available/mcp-ssl
sudo ln -sf /etc/nginx/sites-available/mcp-ssl /etc/nginx/sites-enabled/mcp-ssl

sudo nginx -t
sudo systemctl reload nginx

echo "=== 443 监听 ==="
sudo ss -tlnp | grep ':443' || echo "443 未监听"

BODY='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"httpstest","version":"1.0"}}}'

echo "=== 本地 HTTPS + 对外 key（强制解析到 127.0.0.1，验证证书链）==="
curl -sS -m 15 --resolve "${DOMAIN}:443:127.0.0.1" \
  -o /dev/null -w "https_extkey=%{http_code} tls=%{ssl_verify_result} time=%{time_total}s\n" \
  -X POST "https://${DOMAIN}/mcp" \
  -H "Authorization: Bearer ${MCP_KEY}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "$BODY" || true

echo "=== 本地 HTTPS 无 key（应 401）==="
curl -sS -m 15 --resolve "${DOMAIN}:443:127.0.0.1" \
  -o /dev/null -w "https_nokey=%{http_code}\n" \
  -X POST "https://${DOMAIN}/mcp" -H "Content-Type: application/json" -d '{}' || true

echo "=== 从服务器走公网自身 IP 测 443（判断安全组是否放行）==="
timeout 10 bash -c "</dev/tcp/20.255.73.137/443" 2>/dev/null && echo "443 可连" || echo "443 连不上（可能被 Azure 安全组拦截）"
