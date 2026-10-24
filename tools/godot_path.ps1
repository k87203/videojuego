function Resolve-Godot {
    param([string]$Requested = '', [switch]$Console)
    foreach ($candidate in @($Requested, $env:GODOT)) {
        if (-not $candidate) { continue }
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $candidate).ProviderPath }
        $command = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    foreach ($name in @('godot', 'godot4')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    $names = @('Godot_v4.7.2-stable_win64.exe', 'Godot_v4.7.2-stable_win64_console.exe')
    if ($Console) { [array]::Reverse($names) }
    foreach ($name in $names) {
        $candidate = Join-Path (Join-Path $env:USERPROFILE 'Downloads') $name
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}
