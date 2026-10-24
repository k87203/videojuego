param([string]$Godot = '', [switch]$Routes, [switch]$Combat, [switch]$Expansion, [switch]$Matrix, [switch]$Remaster, [switch]$Fixes, [switch]$Mejoras, [switch]$Incentives, [switch]$Music)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$Godot = Resolve-Godot -Requested $Godot -Console
if (-not $Godot) { throw 'Godot not found. Use -Godot, GODOT or PATH.' }
if ($Music) {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot --music
} elseif ($Incentives) {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot --incentives
} elseif ($Mejoras) {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot --mejoras
} elseif ($Fixes) {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot --fixes
} elseif ($Remaster) {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot --remaster
} elseif ($Matrix) {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot --matrix
} elseif ($Expansion) {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot --expansion
} elseif ($Combat) {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot --combat
} elseif ($Routes) {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot --routes
} else {
    python (Join-Path $PSScriptRoot 'check.py') --godot $Godot
}
exit $LASTEXITCODE
