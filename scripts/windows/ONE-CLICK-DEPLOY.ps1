# 一键部署（Windows 双击或 PowerShell）
# 用本机 PEM 连接 Azure，上传 amd-radeon-register，启动 MCP + 隧道

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/2716399563/gbd-config.git"
$CloneDir = "$env:USERPROFILE\dev\gbd-config"

if (-not (Test-Path $CloneDir)) {
    git clone $RepoUrl $CloneDir
} else {
    Set-Location $CloneDir
    git pull origin main
}

Set-Location $CloneDir
powershell -ExecutionPolicy Bypass -File .\scripts\windows\upload-and-deploy.ps1

Write-Host ""
Write-Host "若成功，请把上方 trycloudflare.com 地址发给 Cursor Agent" -ForegroundColor Green
