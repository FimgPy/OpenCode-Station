@echo off
chcp 65001 >nul
setlocal
title OpenCode Station - GUI
cd /d "%~dp0"

echo ==============================================================================
echo                      OpenCode Station - GUI launcher
echo                      Made by Anton Kovalkin. All rights reserved.
echo ==============================================================================
echo.

set "CURR_DIR=%~dp0"
set "CURR_DIR=%CURR_DIR:\=/%"
for /f "usebackq delims=" %%i in (`wsl.exe wslpath "%CURR_DIR%"`) do set "WSL_SRC=%%i"

echo [*] Stopping previous station processes...
wsl.exe -u dev -- bash -lc "python3 /usr/local/bin/stationctl stop >/dev/null 2>&1 || true"

echo [*] Starting GUI server (it starts the web terminal itself)...
start "" /b wsl.exe -u dev -- bash -lc "python3 -u /usr/local/bin/opencode-gui-server --port 7682"

echo [*] Waiting for http://localhost:7682 ...
powershell -NoProfile -Command "$ok=$false; for ($i=0; $i -lt 40; $i++) { try { $r=[System.Net.WebRequest]::Create('http://127.0.0.1:7682/api/ping'); $r.Timeout=1200; $res=$r.GetResponse(); if($res.StatusCode -eq 200){$ok=$true; break} } catch {} Start-Sleep -Milliseconds 500 }; if (-not $ok) { exit 1 }"
if %errorlevel% neq 0 (
    echo.
    echo [!] GUI did not answer on port 7682.
    echo     Make sure setup.bat completed and WSL is running.
    echo     Log: wsl -u dev -- tail -n 80 /var/envs/run/gui.log
    pause
    exit /b 1
)

echo.
echo ==============================================================================
echo [+] OpenCode Station is running.
echo     GUI        : http://localhost:7682
echo     Terminal   : http://localhost:7681
echo     Stop       : stop.bat
echo ==============================================================================
start "" http://localhost:7682
echo.
echo [i] This window can be closed; the GUI server keeps running in WSL.
timeout /t 3 >nul
endlocal
