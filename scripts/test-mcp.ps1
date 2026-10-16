<#
.SYNOPSIS
  Smoke-tests a running PingPal MCP endpoint: initialize, tools/list and every tool.

.EXAMPLE
  ./scripts/test-mcp.ps1
  ./scripts/test-mcp.ps1 -Port 9000 -Token secret -SkipAsk
#>
param(
  [int]$Port = 7464,
  [string]$Token = "",
  [switch]$SkipAsk   # `ask` waits for a click (or its timeout); skip it for fast runs
)

$ErrorActionPreference = "Stop"
$base = "http://127.0.0.1:$Port"
$script:failures = 0
$script:session = $null

function Check([bool]$ok, [string]$what) {
  if ($ok) { Write-Host "  PASS  $what" -ForegroundColor Green }
  else { Write-Host "  FAIL  $what" -ForegroundColor Red; $script:failures++ }
}

function Invoke-Mcp([hashtable]$Body, [int]$TimeoutSec = 30) {
  $headers = @{ "Accept" = "application/json, text/event-stream" }
  if ($Token) { $headers["Authorization"] = "Bearer $Token" }
  if ($script:session) { $headers["Mcp-Session-Id"] = $script:session }
  Invoke-WebRequest -Uri "$base/mcp" -Method Post -ContentType "application/json" `
    -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10 -Compress) -UseBasicParsing -TimeoutSec $TimeoutSec
}

function Invoke-Tool([string]$Name, [hashtable]$Arguments, [int]$Id, [int]$TimeoutSec = 30) {
  $response = Invoke-Mcp @{ jsonrpc = "2.0"; id = $Id; method = "tools/call"
    params = @{ name = $Name; arguments = $Arguments } } $TimeoutSec
  ($response.Content | ConvertFrom-Json).result
}

Write-Host "PingPal MCP smoke test against $base/mcp"

try {
  $health = Invoke-RestMethod "$base/health" -TimeoutSec 5
  Check ($health.ok -eq $true) "GET /health -> ok ($($health.name) $($health.version))"
} catch {
  Write-Host "Cannot reach PingPal on port $Port. Is it running?  ($($_.Exception.Message))" -ForegroundColor Red
  exit 2
}

$init = Invoke-Mcp @{ jsonrpc = "2.0"; id = 1; method = "initialize"; params = @{
    protocolVersion = "2025-06-18"; capabilities = @{}
    clientInfo = @{ name = "pingpal-test-script"; title = "Test Script"; version = "1.0" } } }
$script:session = @($init.Headers["Mcp-Session-Id"])[0]
$initBody = $init.Content | ConvertFrom-Json
Check ($init.StatusCode -eq 200 -and $initBody.result.serverInfo.name -eq "pingpal") "initialize -> serverInfo.name = pingpal"
Check ([bool]$script:session) "initialize issues an Mcp-Session-Id"

$note = Invoke-Mcp @{ jsonrpc = "2.0"; method = "notifications/initialized" }
Check ($note.StatusCode -eq 202) "notifications/initialized -> 202 Accepted"

$list = (Invoke-Mcp @{ jsonrpc = "2.0"; id = 2; method = "tools/list" }).Content | ConvertFrom-Json
$names = ($list.result.tools | ForEach-Object { $_.name } | Sort-Object) -join ","
Check ($names -eq "ask,clear,notify,perform,set_state") "tools/list -> $names"

$r = Invoke-Tool "set_state" @{ status = "working"; text = "running the test script" } 3
Check (-not $r.isError) "set_state working"
$r = Invoke-Tool "notify" @{ text = "Hello from the smoke test!"; mood = "happy" } 4
Check (-not $r.isError) "notify: $($r.content[0].text)"
$r = Invoke-Tool "perform" @{ action = "wave" } 5
Check (-not $r.isError) "perform wave"
$r = Invoke-Tool "notify" @{ text = "bad mood"; mood = "furious" } 6
Check ($r.isError -eq $true) "invalid arguments come back as isError: $($r.content[0].text)"

if (-not $SkipAsk) {
  Write-Host "  ...   ask: click a button on the character within 8s (or let it time out)"
  $r = Invoke-Tool "ask" @{ question = "Does the smoke test look good?"; choices = @("Yes", "No"); timeout_seconds = 8 } 7 20
  $answer = $r.content[0].text | ConvertFrom-Json
  Check (-not $r.isError) "ask returned: $($r.content[0].text)"
}

$r = Invoke-Tool "set_state" @{ status = "done"; text = "Smoke test finished" } 8
Check (-not $r.isError) "set_state done"
$r = Invoke-Tool "clear" @{} 9
Check (-not $r.isError) "clear"

Invoke-WebRequest -Uri "$base/mcp" -Method Delete -Headers @{ "Mcp-Session-Id" = $script:session } -UseBasicParsing | Out-Null

if ($script:failures -eq 0) { Write-Host "`nAll checks passed." -ForegroundColor Green; exit 0 }
Write-Host "`n$($script:failures) check(s) failed." -ForegroundColor Red
exit 1
