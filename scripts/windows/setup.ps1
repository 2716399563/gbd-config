# Windows 本机初始化：克隆仓库并检查 Git
# 用法: .\setup.ps1 [-RepoUrl "https://github.com/2716399563/gbd-config.git"] [-TargetDir "C:\dev\gbd-config"]

param(
    [string]$RepoUrl = "https://github.com/2716399563/gbd-config.git",
    [string]$TargetDir = "$env:USERPROFILE\dev\gbd-config"
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "未找到 Git。请安装 https://git-scm.com/download/win"
}

if (Test-Path $TargetDir) {
    Write-Host "目录已存在: $TargetDir" -ForegroundColor Yellow
    Set-Location $TargetDir
} else {
    Write-Host "克隆仓库到 $TargetDir ..." -ForegroundColor Cyan
    $parent = Split-Path $TargetDir -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    git clone $RepoUrl $TargetDir
    Set-Location $TargetDir
}

Write-Host ""
Write-Host "Windows 侧无需安装 cloudflared。" -ForegroundColor Green
Write-Host "文件同步: 在服务器跑 MCP，Cloud Agent 改服务器文件；本机执行 .\scripts\windows\sync.ps1 从 GitHub 拉取。" -ForegroundColor Green
Write-Host ""
Write-Host "下一步: 在 Linux 服务器执行 scripts/server/setup.sh" -ForegroundColor Cyan
