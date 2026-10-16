#!/usr/bin/env bash
# Smoke-tests a running PingPal MCP endpoint with plain curl (macOS / Linux / Git Bash).
#   ./scripts/test-mcp.sh [port]
set -u
PORT="${1:-7464}"
URL="http://127.0.0.1:${PORT}/mcp"
fail=0

post() { # post <session-or-empty> <json>
  local headers=(-H "Content-Type: application/json" -H "Accept: application/json, text/event-stream")
  [ -n "$1" ] && headers+=(-H "Mcp-Session-Id: $1")
  curl -s -i "${headers[@]}" -d "$2" "$URL"
}
check() { if [ "$1" = "0" ]; then echo "  PASS  $2"; else echo "  FAIL  $2"; fail=1; fi; }

echo "PingPal MCP smoke test against $URL"
curl -sf "http://127.0.0.1:${PORT}/health" >/dev/null || { echo "Cannot reach PingPal on port $PORT. Is it running?"; exit 2; }

init=$(post "" '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl-test","version":"1"}}}')
session=$(printf '%s' "$init" | tr -d '\r' | awk -F': ' 'tolower($1)=="mcp-session-id"{print $2}')
printf '%s' "$init" | grep -q '"name":"pingpal"'; check $? "initialize -> serverInfo.name = pingpal"
[ -n "$session" ]; check $? "initialize issues an Mcp-Session-Id ($session)"

post "$session" '{"jsonrpc":"2.0","method":"notifications/initialized"}' | head -1 | grep -q 202; check $? "notifications/initialized -> 202"

post "$session" '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | grep -q '"name":"set_state"'; check $? "tools/list lists set_state"
post "$session" '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"set_state","arguments":{"source":"curl-test","status":"working"}}}' | grep -q '"isError":false'; check $? "set_state working"
post "$session" '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"notify","arguments":{"source":"curl-test","text":"Hello from curl!"}}}' | grep -q '"isError":false'; check $? "notify"
post "$session" '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"notify","arguments":{"text":"no source"}}}' | grep -q '"isError":true'; check $? "a call without source is rejected"
post "$session" '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"set_state","arguments":{"source":"curl-test","status":"done","text":"curl finished"}}}' | grep -q '"isError":false'; check $? "set_state done"
post "$session" '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"clear","arguments":{"source":"curl-test"}}}' | grep -q '"isError":false'; check $? "clear"

[ "$fail" = "0" ] && echo "All checks passed." || echo "Some checks failed."
exit $fail
