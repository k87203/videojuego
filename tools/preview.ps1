param([int]$Level = 0, [int]$Position = 180, [string]$Name = 'menu', [string]$Character = 'alex', [switch]$Characters, [switch]$Graduation, [switch]$Exported, [switch]$Walk)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path $PSScriptRoot -Parent
$godotExe = 'C:\Users\uriel\Downloads\Godot_v4.7.2-stable_win64_console.exe'
$capturePath = Join-Path $projectDir "docs\$Name.png"
$arguments = @('--path', $projectDir, '--', '--test', "--capture=$capturePath", '--capture-at=180')
if ($Walk) {
    if ($Exported) { throw 'The moving probe is a source-only test scene.' }
    $arguments = @('--path', $projectDir, 'res://tests/render_walk.tscn', '--', '--test', "--capture=$capturePath", '--capture-at=720')
}
if ($Exported) {
    $godotExe = Join-Path $projectDir 'build\Windows\TECNO_AVENTURA_III_0.4.1.exe'
    $arguments = @('--', '--test', "--capture=$capturePath", '--capture-at=180')
}
if ($Level -gt 0) { $arguments += "--level=$Level"; $arguments += "--position=$Position" }
if ($Graduation) { $arguments += '--graduation' }
$arguments += "--character=$Character"
if ($Characters) { $arguments += '--characters' }
$proc = Start-Process -FilePath $godotExe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $projectDir "docs\$Name-render.log") -RedirectStandardError (Join-Path $projectDir "docs\$Name-errors.log")
if (-not $proc.WaitForExit(30000)) { Stop-Process -Id $proc.Id; throw 'Screenshot timed out' }
Get-Content -LiteralPath (Join-Path $projectDir "docs\$Name-render.log"),(Join-Path $projectDir "docs\$Name-errors.log")
$renderErrors = Get-Content -Raw -LiteralPath (Join-Path $projectDir "docs\$Name-errors.log")
if (($null -ne $proc.ExitCode -and $proc.ExitCode -ne 0) -or $renderErrors -match 'ERROR:|SCRIPT ERROR:|Leaked|still in use') { throw 'Render verification failed; inspect the error log.' }
if (-not (Test-Path -LiteralPath $capturePath)) { throw 'Screenshot was not produced.' }
