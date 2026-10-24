param([string]$Godot = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'godot_path.ps1')
$projectDir = Split-Path $PSScriptRoot -Parent
$engine = Resolve-Godot -Requested $Godot
if ($engine) {
    Start-Process -FilePath $engine -ArgumentList @('--path', ('"' + $projectDir + '"')) -WorkingDirectory $projectDir -WindowStyle Normal
    exit 0
}
$release = Join-Path $projectDir 'build\Windows\TECNO_AVENTURA_III.exe'
if (Test-Path -LiteralPath $release -PathType Leaf) {
    Start-Process -FilePath $release -WorkingDirectory (Split-Path $release -Parent) -WindowStyle Normal
    exit 0
}
throw 'No se encontro Godot. Instala Godot 4.7.2, configura GODOT o PATH, o abre project.godot en el editor y pulsa F5.'
