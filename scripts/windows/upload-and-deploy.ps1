# 从 Windows 用 PEM 把 amd-radeon-register 上传到服务器并启动 MCP + cloudflared
# 用法:
#   .\upload-and-deploy.ps1 -ServerHost <IP或域名> [-SshUser root]
#
# 默认使用你提供的路径：
#   PEM:  C:\Users\Administrator\Desktop\amd-radeon\amd-radeon-register\huangshibo.pem
#   项目: C:\Users\Administrator\Desktop\amd-radeon\amd-radeon-register

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerHost,

    [string]$SshUser = "root",

    [string]$PemPath = "C:\Users\Administrator\Desktop\amd-radeon\amd-radeon-register\huangshibo.pem",

    [string]$ProjectPath = "C:\Users\Administrator\Desktop\amd-radeon\amd-radeon-register",

    [string]$RemotePath = "/opt/amd-radeon-register"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $PemPath)) {
    Write-Error "找不到 PEM: $PemPath"
}
if (-not (Test-Path $ProjectPath)) {
    Write-Error "找不到项目目录: $ProjectPath"
}

$ssh = "ssh -i `"$PemPath`" -o StrictHostKeyChecking=accept-new ${SshUser}@${ServerHost}"
$scp = "scp -i `"$PemPath`" -o StrictHostKeyChecking=accept-new"

Write-Host "==> 测试 SSH 连接 $SshUser@$ServerHost ..." -ForegroundColor Cyan
Invoke-Expression "$ssh 'echo ok && uname -a'"

Write-Host "==> 创建远程目录 $RemotePath ..." -ForegroundColor Cyan
Invoke-Expression "$ssh 'mkdir -p $RemotePath'"

Write-Host "==> 上传项目（排除 .git、*.pem）..." -ForegroundColor Yellow
$tarArgs = @("-cf", "-", "--exclude=.git", "--exclude=*.pem", "-C", $ProjectPath, ".")
$remoteCmd = "mkdir -p $RemotePath && cd $RemotePath && tar -xf -"
& tar @tarArgs | & ssh -i $PemPath -o StrictHostKeyChecking=accept-new "${SshUser}@${ServerHost}" $remoteCmd

Write-Host "==> 上传服务器部署脚本 ..." -ForegroundColor Cyan
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Invoke-Expression "$scp -r `"$RepoRoot\scripts\server`" ${SshUser}@${ServerHost}:/tmp/gbd-mcp-server-scripts"

Write-Host "==> 远程安装 Docker（若未装）并启动 MCP ..." -ForegroundColor Green
$remoteSetup = @"
set -euo pipefail
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker 2>/dev/null || true
fi
mkdir -p /tmp/gbd-mcp-server-scripts
if [ ! -f /tmp/gbd-mcp-server-scripts/.env ]; then
  cp /tmp/gbd-mcp-server-scripts/.env.example /tmp/gbd-mcp-server-scripts/.env
  echo '请在服务器编辑 /tmp/gbd-mcp-server-scripts/.env 填入 CLOUDFLARED_TUNNEL_TOKEN 后执行:'
  echo '  cd /tmp/gbd-mcp-server-scripts && docker compose --env-file .env up -d'
fi
WORKSPACE_PATH=$RemotePath
sed -i "s|^WORKSPACE_PATH=.*|WORKSPACE_PATH=$RemotePath|" /tmp/gbd-mcp-server-scripts/.env
cd /tmp/gbd-mcp-server-scripts
if grep -q '^CLOUDFLARED_TUNNEL_TOKEN=.\+' .env; then
  docker compose --env-file .env up -d
  docker compose ps
else
  echo 'WARN: CLOUDFLARED_TUNNEL_TOKEN 为空，已跳过 docker compose up'
fi
"@

Invoke-Expression "$ssh `"$remoteSetup`""

Write-Host ""
Write-Host "==> 完成" -ForegroundColor Green
Write-Host "远程项目: $RemotePath"
Write-Host "若 Tunnel 未启动，在服务器执行:"
Write-Host "  ssh -i `"$PemPath`" ${SshUser}@${ServerHost}"
Write-Host "  nano /tmp/gbd-mcp-server-scripts/.env   # 填入 CLOUDFLARED_TUNNEL_TOKEN"
Write-Host "  cd /tmp/gbd-mcp-server-scripts && docker compose --env-file .env up -d"
