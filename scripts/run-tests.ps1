<#
.SYNOPSIS
  Runs the headless unit/integration tests (packs, idle brain, hub, MCP protocol + HTTP).

.EXAMPLE
  ./scripts/run-tests.ps1                         # uses $env:GODOT or `godot` on PATH
  ./scripts/run-tests.ps1 -Godot S:\Godot\Godot_v4.7.1-stable_win64_console.exe
#>
param([string]$Godot = $(if ($env:GODOT) { $env:GODOT } else { "godot" }))

$root = Split-Path -Parent $PSScriptRoot
& $Godot --headless --path $root --import 2>&1 | Out-Null
& $Godot --headless --path $root --script res://tests/run_tests.gd
exit $LASTEXITCODE
