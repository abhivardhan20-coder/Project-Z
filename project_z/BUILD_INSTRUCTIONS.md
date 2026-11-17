# Build and validate on Windows

Use the [Godot 4.7.2 Windows editor and export templates](https://godotengine.org/download/archive/4.7.2-stable/) and Python 3.11+. Install the standard templates in the editor, or pass the matching Windows release template directly. Run the commands from the `project_z` directory.

```powershell
$godot = 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe'
python tools/asset_validation/validate_glb.py
& $godot --path . --fixed-fps 60 --script res://tests/startup.gd
& $godot --headless --path . --fixed-fps 60 --script res://tests/p06.gd
& $godot --headless --path . --fixed-fps 60 --script res://tests/furnished_safehouse.gd
& $godot --headless --path . --fixed-fps 60 --script res://tests/city_integration.gd
python tools/build/build_windows.py --godot $godot
```

For a template supplied as a standalone file, add `--template C:\path\to\windows_release_x86_64.exe` to the build command. The build script stages source GLB bytes under an exportable extension, invokes the Windows Desktop preset, and writes `builds/windows/ProjectZ.exe`, `ProjectZ.pck` and the license notice. The editor project retains normal GLB extensions. The export uses the standard Godot runtime and is unsigned.

```powershell
$exe = (Resolve-Path 'builds/windows/ProjectZ.exe').Path
$log = Join-Path (Get-Location).Path 'windows-smoke.log'
$smoke = Start-Process -FilePath $exe -ArgumentList "--headless --fixed-fps 60 --quit-after 120 --log-file `"$log`" -- --city-test" -PassThru -Wait
Get-Content $log
$smoke.ExitCode
```

The smoke test prints `Kaldran smoke ready` after the world and player are initialized. It uses an isolated test save location. To play, launch the executable without arguments.
