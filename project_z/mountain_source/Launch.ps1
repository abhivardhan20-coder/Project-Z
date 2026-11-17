param([ValidateSet('Play','Editor','CityReview','Check')][string]$Mode = 'Play')
$projectRoot = Split-Path $PSScriptRoot -Parent
if ($Mode -eq 'Check') { Write-Output "Project: $projectRoot"; exit 0 }
if ($Mode -eq 'Editor') { & (Join-Path $projectRoot 'Play_Project_Z.ps1') -Editor }
elseif ($Mode -eq 'Play') { & (Join-Path $projectRoot 'Play_Project_Z.ps1') -ReviewMountains }
else { & (Join-Path $projectRoot 'Play_Project_Z.ps1') }
