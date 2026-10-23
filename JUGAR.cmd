@echo off
setlocal
if exist "%~dp0build\Windows\TECNO_AVENTURA_III_0.4.1.exe" (
    start "TECNO AVENTURA III" "%~dp0build\Windows\TECNO_AVENTURA_III_0.4.1.exe"
    exit /b 0
)
if exist "%~dp0build\Windows\TECNO_AVENTURA_III_0.4.exe" (
    start "TECNO AVENTURA III" "%~dp0build\Windows\TECNO_AVENTURA_III_0.4.exe"
    exit /b 0
)
if exist "%~dp0build\Windows\TECNO_AVENTURA_III_0.3.exe" (
    start "TECNO AVENTURA III" "%~dp0build\Windows\TECNO_AVENTURA_III_0.3.exe"
    exit /b 0
)
if exist "%~dp0build\Windows\TECNO_AVENTURA_III.exe" (
    start "TECNO AVENTURA III" "%~dp0build\Windows\TECNO_AVENTURA_III.exe"
    exit /b 0
)
set "TECNO_GODOT=C:\Users\uriel\Downloads\Godot_v4.7.2-stable_win64.exe"
if exist "%TECNO_GODOT%" (
    start "TECNO AVENTURA III" "%TECNO_GODOT%" --path "%~dp0."
    exit /b 0
)
where godot >nul 2>nul
if not errorlevel 1 (
    start "TECNO AVENTURA III" godot --path "%~dp0."
    exit /b 0
)
echo Abre project.godot con Godot 4 y pulsa F6 desde main.tscn o F5.
pause
