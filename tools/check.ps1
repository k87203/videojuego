param([string]$Godot = 'C:\Users\uriel\Downloads\Godot_v4.7.2-stable_win64_console.exe', [switch]$Routes, [switch]$Combat, [switch]$Expansion, [switch]$Matrix, [switch]$Remaster)
$ErrorActionPreference = 'Stop'
if ($Remaster) {
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
