#!/usr/bin/env python3
import json, os, time, statistics, urllib.request

AUTH = "Bearer " + os.environ.get("MCP_KEY", "REPLACE_WITH_YOUR_KEY")
INIT = json.dumps({
    "jsonrpc": "2.0", "id": 1, "method": "initialize",
    "params": {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "bench", "version": "1.0"},
    },
}).encode()
HEADERS = {
    "Content-Type": "application/json",
    "Accept": "application/json, text/event-stream",
    "Authorization": AUTH,
}

def bench(name, url, n=8):
    times, ok = [], 0
    for _ in range(n):
        req = urllib.request.Request(url, data=INIT, headers=HEADERS, method="POST")
        t0 = time.perf_counter()
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                r.read(400)
            ms = (time.perf_counter() - t0) * 1000
            times.append(ms)
            ok += 1
        except Exception as e:
            print(f"  err: {e}")
    if not times:
        print(f"{name}: FAILED")
        return
    s = sorted(times)
    p95 = s[max(0, int(len(s) * 0.95) - 1)]
    print(f"{name}: ok={ok}/{n}  min={min(times):.0f}ms  avg={statistics.mean(times):.0f}ms  p95={p95:.0f}ms  max={max(times):.0f}ms")

print("=== Server benchmark ===")
bench("direct 127.0.0.1:8001/mcp", "http://127.0.0.1:8001/mcp")
bench("nginx  127.0.0.1/mcp", "http://127.0.0.1/mcp")
