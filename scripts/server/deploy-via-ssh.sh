#!/usr/bin/env bash
# Cloud Agent 远程部署到 Azure 服务器
set -euo pipefail

SERVER_HOST="${SERVER_HOST:-20.255.73.137}"
SSH_USER="${SSH_USER:-azureuser}"
REMOTE_PATH="${REMOTE_PATH:-/opt/amd-radeon-register}"
REMOTE_STACK="/tmp/gbd-mcp-server-scripts"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"

if [[ -z "${SSH_PRIVATE_KEY:-}" ]]; then
  echo "错误: 需要 SSH_PRIVATE_KEY（huangshibo.pem 全文，Cursor Runtime Secret）"
  exit 1
fi

KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s\n' "$SSH_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

SSH_BASE=(-i "$KEY_FILE" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)
SSH_TARGET="${SSH_USER}@${SERVER_HOST}"

run_ssh() {
  ssh "${SSH_BASE[@]}" "${SSH_TARGET}" "$@"
}

echo "==> 测试 SSH (${SSH_TARGET})..."
if ! run_ssh 'echo ok && uname -a'; then
  if [[ "${SSH_USER}" != "root" ]]; then
    SSH_USER=root
    SSH_TARGET="${SSH_USER}@${SERVER_HOST}"
    run_ssh 'echo ok && uname -a'
  else
    exit 1
  fi
fi

echo "==> 安装 Docker（若需要）..."
run_ssh 'command -v docker >/dev/null 2>&1 || (curl -fsSL https://get.docker.com | sh && systemctl enable --now docker 2>/dev/null || true)'

echo "==> 上传部署文件..."
run_ssh "mkdir -p ${REMOTE_STACK}"
scp "${SSH_BASE[@]}" -r \
  "${SCRIPT_DIR}/docker-compose.yml" \
  "${SCRIPT_DIR}/docker-compose.quick.yml" \
  "${SCRIPT_DIR}/.env.example" \
  "${SSH_USER}@${SERVER_HOST}:${REMOTE_STACK}/"

echo "==> 启动 MCP + Tunnel..."
run_ssh bash -s <<REMOTE
set -euo pipefail
REMOTE_PATH="${REMOTE_PATH}"
STACK="${REMOTE_STACK}"
TOKEN="${CLOUDFLARED_TUNNEL_TOKEN:-}"

mkdir -p "\${REMOTE_PATH}"
cd "\${STACK}"
cp -n .env.example .env 2>/dev/null || cp .env.example .env
sed -i "s|^WORKSPACE_PATH=.*|WORKSPACE_PATH=\${REMOTE_PATH}|" .env
if [[ -n "\${TOKEN}" ]]; then
  sed -i "s|^CLOUDFLARED_TUNNEL_TOKEN=.*|CLOUDFLARED_TUNNEL_TOKEN=\${TOKEN}|" .env
fi

docker compose --env-file .env up -d mcp-gateway

if grep -q '^CLOUDFLARED_TUNNEL_TOKEN=.\+' .env; then
  docker compose --env-file .env up -d cloudflared
else
  docker compose -f docker-compose.yml -f docker-compose.quick.yml --env-file .env up -d cloudflared-quick
  sleep 8
  docker logs gbd-cloudflared-quick 2>&1 | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | head -1 || true
fi
docker compose ps
REMOTE

echo "==> 同步 gbd-config 到工作区..."
tar -cf - -C "${REPO_ROOT}" --exclude=.git . \
  | ssh "${SSH_BASE[@]}" "${SSH_TARGET}" \
    "mkdir -p ${REMOTE_PATH}/gbd-config && cd ${REMOTE_PATH}/gbd-config && tar -xf -"

echo "==> 部署完成"
