## Builds the Windows release: exports PingPal and zips it with its licences.
##   pwsh -File scripts/build-release.ps1
## Output: build/PingPal-<version>-windows.zip (version from project.godot) and a SHA-256 file
## beside it. The engine comes from $env:GODOT or godot / godot4 on PATH, and the Windows export
## templates for that engine version must be installed (scripts/install-godot.ps1 does both).
## The exe is one self-contained file: the game's data is embedded.

$ErrorActionPreference = "Stop"

function Resolve-Godot {
	if ($env:GODOT -and (Test-Path -LiteralPath $env:GODOT -PathType Leaf)) {
		return (Resolve-Path -LiteralPath $env:GODOT).Path
	}
	foreach ($name in @("godot_console", "godot", "godot4")) {
		$command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue |
			Select-Object -First 1
		if ($command) {
			return $command.Source
		}
	}
	$Host.UI.WriteErrorLine("No Godot binary found. Set `$env:GODOT or put godot on PATH.")
	exit 2
}

$godot = Resolve-Godot
$repo = Split-Path $PSScriptRoot -Parent
$build = Join-Path $repo "build"

$version = (Select-String -Path (Join-Path $repo "project.godot") -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
$name = "PingPal-$version-windows"
$exe = Join-Path $build "PingPal.exe"
$zip = Join-Path $build "$name.zip"

if (Test-Path -LiteralPath $build) {
	Remove-Item -LiteralPath $build -Recurse -Force
}
New-Item -ItemType Directory -Path $build | Out-Null

# Import first, so a fresh clone has its texture imports before exporting.
& $godot --headless --path $repo --import 2>&1 | Out-Null
$log = & $godot --headless --path $repo --export-release "Windows Desktop" $exe 2>&1 | Out-String
if (-not (Test-Path -LiteralPath $exe)) {
	Write-Host $log
	$Host.UI.WriteErrorLine("Export failed: no PingPal.exe was written.")
	exit 1
}
if ($log -match "SCRIPT ERROR|Parse Error|ERROR:") {
	Write-Host $log
	$Host.UI.WriteErrorLine("Export printed errors (above). Fix them before releasing.")
	exit 1
}

# Zip the exe with what a user and the licences need, inside one folder.
$stage = Join-Path $build $name
New-Item -ItemType Directory -Path $stage | Out-Null
Copy-Item $exe $stage
Copy-Item (Join-Path $repo "LICENSE") $stage
Copy-Item (Join-Path $repo "THIRD_PARTY_NOTICES.md") $stage
Copy-Item (Join-Path $repo "PLAYING.md") (Join-Path $stage "README.txt")
Copy-Item (Join-Path $repo "docs/AGENT_INSTRUCTIONS.md") $stage
Copy-Item (Join-Path $repo "skills") $stage -Recurse
Compress-Archive -Path $stage -DestinationPath $zip
Remove-Item -LiteralPath $stage -Recurse -Force

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLower()
"$hash  $name.zip" | Set-Content -Path "$zip.sha256" -Encoding ascii
$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host "Built $zip ($size MB)"
Write-Host "SHA-256 $hash"
