# Auto-retry SSH recovery for stuck MCP gateway
$ErrorActionPreference = "Continue"
$PemPath = "C:\Users\Administrator\Desktop\amd-radeon\amd-radeon-register\huangshibo.pem"
$Server = "huangshibo@20.255.73.137"
$MaxAttempts = 30

$RecoverCmd = @'
set -eu
sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd
sudo docker restart gbd-mcp-gateway
sleep 12
echo "=== docker ==="
sudo docker ps --format 'table {{.Names}}\t{{.Status}}'
echo "=== nginx bench ==="
for i in 1 2 3 4 5; do
  curl -sS -m 8 -o /dev/null -w "nginx#$i %{http_code} %{time_total}s\n" \
    -X POST http://127.0.0.1/mcp \
    -H "Authorization: Bearer REPLACE_WITH_YOUR_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bench","version":"1.0"}}}' || echo "nginx#$i FAILED"
done
'@

Write-Host "Auto-recover: retrying SSH up to $MaxAttempts times..." -ForegroundColor Cyan
for ($i = 1; $i -le $MaxAttempts; $i++) {
    Write-Host "[$(Get-Date -Format HH:mm:ss)] attempt $i/$MaxAttempts"
    $null = ssh -i $PemPath -o ConnectTimeout=15 -o BatchMode=yes $Server "echo ok" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SSH OK - restarting MCP..." -ForegroundColor Green
        ($RecoverCmd -replace "`r`n", "`n") | ssh -i $PemPath $Server "bash -s"
        Write-Host "Windows public benchmark..." -ForegroundColor Cyan
        $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bench","version":"1.0"}}}'
        Set-Content -Path "$env:TEMP\mcp-init.json" -Value $body -NoNewline
        $ms = 1..5 | ForEach-Object {
            curl.exe -sS -m 10 -o NUL -w "%{time_total}" -X POST "http://20.255.73.137/mcp" `
                -H "Authorization: Bearer REPLACE_WITH_YOUR_KEY" `
                -H "Content-Type: application/json" `
                -H "Accept: application/json, text/event-stream" `
                --data-binary "@$env:TEMP\mcp-init.json"
        } | ForEach-Object { [double]$_ * 1000 }
        if ($ms.Count -gt 0) {
            $sorted = $ms | Sort-Object
            Write-Host ("public x5: min={0}ms avg={1}ms max={2}ms" -f $sorted[0], [math]::Round(($ms | Measure-Object -Average).Average,0), $sorted[-1])
        }
        Write-Host "Done. Restart Cursor to refresh MCP." -ForegroundColor Green
        exit 0
    }
    Start-Sleep -Seconds 20
}
Write-Host "SSH still down. Run recover-and-bench.sh in Azure Portal." -ForegroundColor Red
exit 1
