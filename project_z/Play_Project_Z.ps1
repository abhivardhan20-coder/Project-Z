param([switch]$ReviewMountains, [switch]$Editor)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$engineCandidates = @(
    (Join-Path (Split-Path (Split-Path $projectRoot -Parent) -Parent) 'Project Z (Godot)\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe'),
    (Join-Path (Split-Path (Split-Path $projectRoot -Parent) -Parent) 'Project Z (Godot)\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe')
)
$enginePath = $engineCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $enginePath) {
    $installed = Get-Command godot -ErrorAction SilentlyContinue
    if ($installed) { $enginePath = $installed.Source }
}
if (-not $enginePath) { throw 'Godot was not found. Open this folder''s project.godot in Godot 4.7.2.' }
$launchArgs = @('--path', ('"' + $projectRoot + '"'))
if ($Editor) { $launchArgs += '--editor' }
elseif ($ReviewMountains) { $launchArgs += 'res://scenes/mountain_prototype.tscn' }
Start-Process -FilePath $enginePath -ArgumentList $launchArgs -WindowStyle Hidden
