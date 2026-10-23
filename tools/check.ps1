param([string]$Godot = 'C:\Users\uriel\Downloads\Godot_v4.7.2-stable_win64_console.exe', [switch]$Routes, [switch]$Combat, [switch]$Expansion, [switch]$Matrix, [switch]$Remaster, [switch]$Fixes, [switch]$Mejoras)
$ErrorActionPreference = 'Stop'
if ($Mejoras) {
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
