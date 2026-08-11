# 反复重试 SSH，一旦连上就重启 MCP 网关并用新内部 key 验证
$ErrorActionPreference = "Continue"
$Pem = "C:\Users\Administrator\Desktop\amd-radeon\amd-radeon-register\huangshibo.pem"
$Server = "huangshibo@20.255.73.137"
$IntKey = if ($env:MCP_KEY) { $env:MCP_KEY } else { "REPLACE_WITH_YOUR_KEY" }
$Max = 40

for ($i = 1; $i -le $Max; $i++) {
    Write-Host "[$(Get-Date -Format HH:mm:ss)] SSH try $i/$Max"
    $null = ssh -i $Pem -o ConnectTimeout=15 -o BatchMode=yes $Server "echo ok" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SSH up. Restarting gateway..." -ForegroundColor Green
        ssh -i $Pem -o ConnectTimeout=20 $Server "sudo docker restart gbd-mcp-gateway; sleep 12; sudo docker ps --format '{{.Names}} {{.Status}}'"
        Start-Sleep 3
        $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1.0"}}}'
        Set-Content -Path "$env:TEMP\mcp-init.json" -Value $body -NoNewline
        curl.exe -sS -m 12 -o NUL -w "public+intkey http=%{http_code} time=%{time_total}s`n" -X POST "http://20.255.73.137/mcp" -H "Authorization: Bearer $IntKey" -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" --data-binary "@$env:TEMP\mcp-init.json"
        Write-Host "RECOVERED" -ForegroundColor Green
        exit 0
    }
    Start-Sleep -Seconds 15
}
Write-Host "SSH still down after retries" -ForegroundColor Red
exit 1
