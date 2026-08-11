#!/usr/bin/env bash
# 在 Azure 虚拟机上一键部署（无需本机 PEM）
# 用法:
#   curl -fsSL https://raw.githubusercontent.com/2716399563/gbd-config/cursor/cloudflare-mcp-setup-fc43/scripts/server/azure-bootstrap.sh | bash
# 或在 Azure 门户 → 虚拟机 → 运行命令 → 粘贴本脚本内容
set -euo pipefail

REMOTE_PATH="${REMOTE_PATH:-/opt/amd-radeon-register}"
REPO_BRANCH="${REPO_BRANCH:-cursor/cloudflare-mcp-setup-fc43}"
INSTALL_DIR="/opt/gbd-mcp-stack"

echo "==> 安装依赖..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git curl ca-certificates

echo "==> 安装 Docker..."
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker 2>/dev/null || true
fi

echo "==> 拉取部署栈..."
rm -rf "${INSTALL_DIR}"
git clone -b "${REPO_BRANCH}" --depth 1 https://github.com/2716399563/gbd-config.git "${INSTALL_DIR}"
cd "${INSTALL_DIR}/scripts/server"

mkdir -p "${REMOTE_PATH}"
cp -n .env.example .env 2>/dev/null || cp .env.example .env
sed -i "s|^WORKSPACE_PATH=.*|WORKSPACE_PATH=${REMOTE_PATH}|" .env

echo "==> 启动 MCP 网关..."
docker compose --env-file .env up -d mcp-gateway

if grep -q '^CLOUDFLARED_TUNNEL_TOKEN=.\+' .env; then
  echo "==> 启动 Cloudflare Tunnel (token)..."
  docker compose --env-file .env up -d cloudflared
else
  echo "==> 无 Tunnel Token，启动临时 quick tunnel..."
  docker compose -f docker-compose.yml -f docker-compose.quick.yml --env-file .env up -d cloudflared-quick
  sleep 8
  URL="$(docker logs gbd-cloudflared-quick 2>&1 | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' | head -1 || true)"
  if [[ -n "${URL}" ]]; then
    echo ""
    echo "=========================================="
    echo "临时 MCP 公网地址（测试用）:"
    echo "  ${URL}/mcp"
    echo "填入 .cursor/mcp.json 的 url 字段"
    echo "=========================================="
  else
    echo "WARN: 未能从日志解析 quick tunnel URL，请执行:"
    echo "  docker logs gbd-cloudflared-quick 2>&1 | grep trycloudflare"
  fi
fi

docker compose ps
echo "==> 工作区: ${REMOTE_PATH}"
echo "==> 下一步: 把 amd-radeon-register 项目上传到 ${REMOTE_PATH}"
