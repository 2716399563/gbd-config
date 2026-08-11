# 保持 SSH 隧道：本机 18001 -> 服务器 MCP 8001
$ErrorActionPreference = "Stop"
$PemPath = "C:\Users\Administrator\Desktop\amd-radeon\amd-radeon-register\huangshibo.pem"
$Server = "huangshibo@20.255.73.137"
$LocalPort = 18001
$RemotePort = 8001

$existing = Get-NetTCPConnection -LocalPort $LocalPort -State Listen -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "隧道已在运行 (端口 $LocalPort)" -ForegroundColor Green
    exit 0
}

Write-Host "启动 MCP SSH 隧道: 127.0.0.1:$LocalPort -> ${Server}:$RemotePort" -ForegroundColor Cyan
Start-Process -WindowStyle Hidden -FilePath "ssh" -ArgumentList @(
    "-i", $PemPath,
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "ServerAliveInterval=30",
    "-N",
    "-L", "${LocalPort}:127.0.0.1:${RemotePort}",
    $Server
)
Start-Sleep -Seconds 2
Write-Host "完成。MCP 地址: http://127.0.0.1:$LocalPort/mcp" -ForegroundColor Green
