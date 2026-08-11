#!/bin/bash
# Azure 门户 → 虚拟机 → 运行命令 → RunShellScript 粘贴运行
set -eu

echo "==> restart ssh + mcp"
sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd
sudo docker restart gbd-mcp-gateway
sleep 12

echo "==> status"
sudo docker ps --format 'table {{.Names}}\t{{.Status}}'

echo "==> benchmark direct :8001 (5x)"
for i in 1 2 3 4 5; do
  curl -sS -m 8 -o /dev/null -w "direct#$i %{http_code} %{time_total}s\n" \
    -X POST http://127.0.0.1:8001/mcp \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bench","version":"1.0"}}}' || echo "direct#$i FAILED"
done

echo "==> benchmark nginx /mcp (5x)"
for i in 1 2 3 4 5; do
  curl -sS -m 8 -o /dev/null -w "nginx#$i %{http_code} %{time_total}s\n" \
    -X POST http://127.0.0.1/mcp \
    -H "Authorization: Bearer mcp-hsb-20260811-k7x9" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bench","version":"1.0"}}}' || echo "nginx#$i FAILED"
done

echo "==> done"
