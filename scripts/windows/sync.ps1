# Windows：从 GitHub 同步 gbd-config 到本机
# 用法: .\sync.ps1 [-Push] [-Branch main]

param(
    [switch]$Push,
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

Set-Location $RepoRoot

if (-not (Test-Path ".git")) {
    Write-Error "当前目录不是 Git 仓库: $RepoRoot"
}

Write-Host "==> 仓库: $RepoRoot" -ForegroundColor Cyan
Write-Host "==> 分支: $Branch" -ForegroundColor Cyan

if ($Push) {
    Write-Host "==> 推送本地更改到 origin/$Branch ..." -ForegroundColor Yellow
    git add -A
    $status = git status --porcelain
    if ($status) {
        $msg = Read-Host "提交说明 (默认: sync from Windows)"
        if (-not $msg) { $msg = "sync from Windows" }
        git commit -m $msg
    }
    git push origin $Branch
}

Write-Host "==> 拉取 origin/$Branch ..." -ForegroundColor Green
git fetch origin
git pull origin $Branch

Write-Host "==> 同步完成" -ForegroundColor Green
git log -1 --oneline
