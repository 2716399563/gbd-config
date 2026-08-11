#!/usr/bin/env bash
# 在 Linux 服务器上一次性部署 MCP + Cloudflare Tunnel
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "请先复制并编辑环境文件:"
  echo "  cp ${SCRIPT_DIR}/.env.example ${ENV_FILE}"
  exit 1
fi

# shellcheck source=/dev/null
source "${ENV_FILE}"

if [[ -z "${CLOUDFLARED_TUNNEL_TOKEN:-}" ]]; then
  echo "错误: 请在 .env 中设置 CLOUDFLARED_TUNNEL_TOKEN"
  exit 1
fi

WORKSPACE_PATH="${WORKSPACE_PATH:-/opt/gbd-config}"
MCP_PORT="${MCP_PORT:-8000}"

if [[ ! -d "${WORKSPACE_PATH}" ]]; then
  echo "工作目录不存在，正在创建并同步仓库到 ${WORKSPACE_PATH} ..."
  sudo mkdir -p "${WORKSPACE_PATH}"
  if command -v git >/dev/null 2>&1; then
    sudo git clone "${REPO_ROOT}" "${WORKSPACE_PATH}" 2>/dev/null || sudo cp -a "${REPO_ROOT}/." "${WORKSPACE_PATH}/"
  else
    sudo cp -a "${REPO_ROOT}/." "${WORKSPACE_PATH}/"
  fi
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "错误: 未安装 Docker。请先安装 Docker Engine 与 docker compose plugin。"
  exit 1
fi

echo "==> 启动 MCP 网关 + cloudflared ..."
cd "${SCRIPT_DIR}"
docker compose --env-file .env up -d --build

echo ""
echo "==> 部署完成"
echo "工作区路径: ${WORKSPACE_PATH}"
echo "本地 MCP 探测: curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:${MCP_PORT}/mcp"
echo ""
echo "下一步:"
echo "  1. 在 Cloudflare Tunnel 中将 Public Hostname 指向 http://mcp-gateway:${MCP_PORT}"
echo "  2. 为该 hostname 配置 Cloudflare Access Service Token"
echo "  3. 在 Cursor Dashboard Secrets 填入 CF_ACCESS_CLIENT_ID / CF_ACCESS_CLIENT_SECRET"
echo "  4. 更新 .cursor/mcp.json 中的 MCP URL"
echo "  5. Windows 运行 scripts/windows/sync.ps1 同步文件"
