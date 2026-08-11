# 等 VM 重启回来 -> 上传修复后的 compose -> 重建网关 -> 用新内部 key 验证 -> 拉起本机 exe
$ErrorActionPreference = "Continue"
$Pem = "C:\Users\Administrator\Desktop\amd-radeon\amd-radeon-register\huangshibo.pem"
$Server = "huangshibo@20.255.73.137"
$IntKey = if ($env:MCP_KEY) { $env:MCP_KEY } else { "REPLACE_WITH_YOUR_KEY" }
$Compose = "C:\Users\Administrator\dev\gbd-config\scripts\server\docker-compose.yml"
$Fix = "C:\Users\Administrator\dev\gbd-config\scripts\server\fix-gateway.sh"
$Exe = "C:\Users\Administrator\Desktop\Cursor-MCP.exe"
$Max = 60

function ToLf($src, $dst) {
    (Get-Content $src -Raw) -replace "`r`n", "`n" | Set-Content -Path $dst -NoNewline -Encoding utf8
}

for ($i = 1; $i -le $Max; $i++) {
    Write-Host "[$(Get-Date -Format HH:mm:ss)] wait SSH $i/$Max"
    $null = ssh -i $Pem -o ConnectTimeout=15 -o BatchMode=yes -o StrictHostKeyChecking=accept-new $Server "echo ok" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SSH up - applying gateway fix" -ForegroundColor Green

        $tmpC = "$env:TEMP\docker-compose.yml"
        $tmpF = "$env:TEMP\fix-gateway.sh"
        ToLf $Compose $tmpC
        ToLf $Fix $tmpF

        scp -i $Pem -o StrictHostKeyChecking=accept-new $tmpC "${Server}:/tmp/docker-compose.yml"
        scp -i $Pem -o StrictHostKeyChecking=accept-new $tmpF "${Server}:/tmp/fix-gateway.sh"
        ssh -i $Pem -o ConnectTimeout=30 $Server "bash /tmp/fix-gateway.sh"

        Write-Host "=== verify public + internal key ===" -ForegroundColor Cyan
        $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"verify","version":"1.0"}}}'
        Set-Content -Path "$env:TEMP\mcp-init.json" -Value $body -NoNewline
        curl.exe -sS -m 20 -o NUL -w "public+intkey=%{http_code} time=%{time_total}s`n" -X POST "http://20.255.73.137/mcp" `
            -H "Authorization: Bearer $IntKey" `
            -H "Content-Type: application/json" `
            -H "Accept: application/json, text/event-stream" `
            --data-binary "@$env:TEMP\mcp-init.json"

        if (Test-Path $Exe) { Start-Process $Exe }
        Write-Host "FIXED-AND-VERIFIED" -ForegroundColor Green
        exit 0
    }
    Start-Sleep -Seconds 20
}
Write-Host "SSH still down after $Max tries" -ForegroundColor Red
exit 1
