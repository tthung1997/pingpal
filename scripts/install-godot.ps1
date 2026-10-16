## Installs a Godot engine for building and testing, with the Windows export templates:
##   pwsh -File scripts/install-godot.ps1 [-Version 4.7.1] [-Dir <folder>]
## Downloads from the official godot-builds release, verifies each file against the published
## SHA-512 sums, puts the console build in <folder> and the Windows templates where the engine
## looks for them (%APPDATA%\Godot\export_templates\<version>.stable). Anything already in place is
## reused. Prints the engine path, and sets GODOT for later steps when run in GitHub Actions.
## Used by .github/workflows/release.yml; also handy on a fresh machine.

param(
	[string]$Version = "4.7.1",
	[string]$Dir = (Join-Path ([IO.Path]::GetTempPath()) "godot-$Version")
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
Add-Type -AssemblyName System.IO.Compression.FileSystem

$base = "https://github.com/godotengine/godot-builds/releases/download/$Version-stable"
$engineZip = "Godot_v$Version-stable_win64.exe.zip"
$engineExe = "Godot_v$Version-stable_win64_console.exe"
$engineMain = "Godot_v$Version-stable_win64.exe"
$templates = "Godot_v$Version-stable_export_templates.tpz"
$templateDir = Join-Path $env:APPDATA "Godot\export_templates\$Version.stable"

New-Item -ItemType Directory -Force -Path $Dir | Out-Null

# name -> expected SHA-512, from the sums file published with the release
$sums = @{}
$raw = (Invoke-WebRequest -UseBasicParsing "$base/SHA512-SUMS.txt").Content
$text = if ($raw -is [byte[]]) { [Text.Encoding]::UTF8.GetString($raw) } else { [string]$raw }
foreach ($line in $text -split "`n") {
	if ($line -match '^([0-9a-fA-F]{128})\s+\*?(.+?)\s*$') { $sums[$Matches[2]] = $Matches[1].ToLower() }
}

function Get-Verified([string]$Name) {
	if (-not $sums.ContainsKey($Name)) { throw "No published checksum for $Name" }
	$path = Join-Path $Dir $Name
	Invoke-WebRequest -UseBasicParsing "$base/$Name" -OutFile $path
	$actual = (Get-FileHash -Algorithm SHA512 -LiteralPath $path).Hash.ToLower()
	if ($actual -ne $sums[$Name]) {
		Remove-Item -LiteralPath $path -Force
		throw "Checksum mismatch for $Name"
	}
	return $path
}

function Expand-Entries([string]$Archive, [string]$Pattern, [string]$Into) {
	New-Item -ItemType Directory -Force -Path $Into | Out-Null
	$zip = [IO.Compression.ZipFile]::OpenRead($Archive)
	try {
		foreach ($entry in $zip.Entries) {
			if ($entry.Name -match $Pattern) {
				[IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $Into $entry.Name), $true)
			}
		}
	}
	finally { $zip.Dispose() }
}

$godot = Join-Path $Dir $engineExe
if (-not (Test-Path -LiteralPath $godot) -or -not (Test-Path -LiteralPath (Join-Path $Dir $engineMain))) {
	$zipPath = Get-Verified $engineZip
	# The console build is a small launcher that needs the main exe beside it.
	Expand-Entries $zipPath ('^(' + [regex]::Escape($engineMain) + '|' + [regex]::Escape($engineExe) + ')$') $Dir
	Remove-Item -LiteralPath $zipPath -Force
}

if (-not (Test-Path -LiteralPath (Join-Path $templateDir "windows_release_x86_64.exe"))) {
	$tpzPath = Get-Verified $templates
	Expand-Entries $tpzPath '^(windows_(debug|release)_x86_64(_console)?\.exe|version\.txt)$' $templateDir
	Remove-Item -LiteralPath $tpzPath -Force
}

if (-not (Test-Path -LiteralPath $godot) -or -not (Test-Path -LiteralPath (Join-Path $templateDir "version.txt"))) {
	throw "Godot $Version did not install correctly"
}
Write-Host "Godot $Version at $godot"
Write-Host "Windows templates in $templateDir"
if ($env:GITHUB_ENV) { "GODOT=$godot" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append }
