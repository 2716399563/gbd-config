#!/usr/bin/env bash
# 用文件传 body，避免多层 shell 转义把 JSON 弄坏
set -eu

DOMAIN="20-255-73-137.sslip.io"
EXT_KEY="${MCP_KEY:-REPLACE_WITH_YOUR_KEY}"

cat > /tmp/mcp-init.json <<'JSON'
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"httpstest","version":"1.0"}}}
JSON

hit() {
  local label="$1"; shift
  curl -sS -m 20 -o /tmp/mcp-out.txt -w "${label}: http=%{http_code} tls_verify=%{ssl_verify_result} time=%{time_total}s\n" "$@" || echo "${label}: FAILED"
}

echo "=== A. HTTPS 本地环回（验证证书链 + 鉴权 + 转发）==="
hit "https_local" --resolve "${DOMAIN}:443:127.0.0.1" \
  -X POST "https://${DOMAIN}/mcp" \
  -H "Authorization: Bearer ${EXT_KEY}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  --data-binary @/tmp/mcp-init.json
head -c 160 /tmp/mcp-out.txt; echo

echo "=== B. HTTPS 走公网自身 IP（探 Azure 安全组是否放行 443）==="
hit "https_public" \
  -X POST "https://${DOMAIN}/mcp" \
  -H "Authorization: Bearer ${EXT_KEY}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  --data-binary @/tmp/mcp-init.json
head -c 160 /tmp/mcp-out.txt; echo

echo "=== C. HTTP 对照（确认老入口仍可用）==="
hit "http_public" \
  -X POST "http://20.255.73.137/mcp" \
  -H "Authorization: Bearer ${EXT_KEY}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  --data-binary @/tmp/mcp-init.json
head -c 160 /tmp/mcp-out.txt; echo
