# 自动重试 SSH 恢复 MCP（服务器 sshd/MCP 卡住时运行）
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
    -H "Authorization: Bearer mcp-hsb-20260811-k7x9" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bench","version":"1.0"}}}' || echo "nginx#$i FAILED"
done
'@

Write-Host "开始自动重试 SSH 恢复 (最多 $MaxAttempts 次)..." -ForegroundColor Cyan
for ($i = 1; $i -le $MaxAttempts; $i++) {
    Write-Host "[$(Get-Date -Format HH:mm:ss)] 尝试 $i/$MaxAttempts ..."
    $test = ssh -i $PemPath -o ConnectTimeout=15 -o BatchMode=yes $Server "echo ok" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SSH 已恢复，正在重启 MCP..." -ForegroundColor Green
        $RecoverCmd | ssh -i $PemPath $Server "bash -s"
        Write-Host ""
        Write-Host "=== Windows 公网测速 ===" -ForegroundColor Cyan
        $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"bench","version":"1.0"}}}'
        Set-Content -Path "$env:TEMP\mcp-init.json" -Value $body -NoNewline
        1..5 | ForEach-Object {
            curl.exe -sS -m 10 -o NUL -w "%{time_total}`n" -X POST "http://20.255.73.137/mcp" `
                -H "Authorization: Bearer mcp-hsb-20260811-k7x9" `
                -H "Content-Type: application/json" `
                -H "Accept: application/json, text/event-stream" `
                --data-binary "@$env:TEMP\mcp-init.json"
        } | ForEach-Object { [double]$_ * 1000 } | Measure-Object -Minimum -Maximum -Average | ForEach-Object {
            Write-Host ("公网 x5: min={0:F0}ms avg={1:F0}ms max={2:F0}ms" -f $_.Minimum, $_.Average, $_.Maximum)
        }
        Write-Host "完成！请重启 Cursor 刷新 MCP。" -ForegroundColor Green
        exit 0
    }
    Start-Sleep -Seconds 20
}
Write-Host "SSH 仍不可用。请在 Azure 门户运行 recover-and-bench.sh" -ForegroundColor Red
exit 1
