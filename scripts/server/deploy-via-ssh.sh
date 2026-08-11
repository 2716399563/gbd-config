#!/usr/bin/env bash
# Cloud Agent 侧：当 Cursor Secrets 已配置 SSH 凭证时，远程部署 MCP
# 需要环境变量:
#   SERVER_HOST, SSH_USER (默认 root), SSH_PRIVATE_KEY (Runtime Secret)
#   CLOUDFLARED_TUNNEL_TOKEN (可选，有则启动 compose)
set -euo pipefail

: "${SERVER_HOST:?需要 SERVER_HOST（Cursor Secret 或环境变量）}"
SSH_USER="${SSH_USER:-root}"
: "${SSH_PRIVATE_KEY:?需要 SSH_PRIVATE_KEY（huangshibo.pem 内容，Runtime Secret）}"

REMOTE_PATH="${REMOTE_PATH:-/opt/amd-radeon-register}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT

printf '%s\n' "$SSH_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

SSH_OPTS=(-i "$KEY_FILE" -o StrictHostKeyChecking=accept-new "${SSH_USER}@${SERVER_HOST}")

echo "==> SSH 测试..."
ssh "${SSH_OPTS[@]}" 'echo ok && uname -a'

echo "==> 上传 deploy 脚本..."
ssh "${SSH_OPTS[@]}" 'mkdir -p /tmp/gbd-mcp-server-scripts'
scp -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new \
  "${SCRIPT_DIR}/docker-compose.yml" \
  "${SCRIPT_DIR}/.env.example" \
  "${SSH_USER}@${SERVER_HOST}:/tmp/gbd-mcp-server-scripts/"

REMOTE_ENV=""
if [[ -n "${CLOUDFLARED_TUNNEL_TOKEN:-}" ]]; then
  REMOTE_ENV="CLOUDFLARED_TUNNEL_TOKEN=${CLOUDFLARED_TUNNEL_TOKEN}"
fi

ssh "${SSH_OPTS[@]}" bash -s <<EOF
set -euo pipefail
REMOTE_PATH="${REMOTE_PATH}"
${REMOTE_ENV:+export CLOUDFLARED_TUNNEL_TOKEN="${CLOUDFLARED_TUNNEL_TOKEN}"}

if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi

mkdir -p "\$REMOTE_PATH"
cd /tmp/gbd-mcp-server-scripts
cp -n .env.example .env 2>/dev/null || true
sed -i "s|^WORKSPACE_PATH=.*|WORKSPACE_PATH=\$REMOTE_PATH|" .env
if [[ -n "\${CLOUDFLARED_TUNNEL_TOKEN:-}" ]]; then
  sed -i "s|^CLOUDFLARED_TUNNEL_TOKEN=.*|CLOUDFLARED_TUNNEL_TOKEN=\$CLOUDFLARED_TUNNEL_TOKEN|" .env
fi

if grep -q '^CLOUDFLARED_TUNNEL_TOKEN=.\+' .env; then
  docker compose --env-file .env up -d
  docker compose ps
else
  echo "CLOUDFLARED_TUNNEL_TOKEN 未设置，跳过 compose"
fi
EOF

echo "==> 远程部署完成"
