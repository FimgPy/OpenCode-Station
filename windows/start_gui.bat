@echo off
chcp 65001 >nul
setlocal
title OpenCode Station - GUI
cd /d "%~dp0"

echo ==============================================================================
echo                  OpenCode Station for Windows - GUI launcher
echo                  Made by Anton Kovalkin. All rights reserved.
echo ==============================================================================
echo.

echo [*] Starting the station (GUI + web terminal)...
wsl.exe -u dev -- bash -lc "python3 /usr/local/bin/stationctl start --no-browser"
if %errorlevel% neq 0 (
    echo.
    echo [!] The station did not start.
    echo     1. Run setup.bat once.
    echo     2. Check WSL: wsl -u dev -- python3 /usr/local/bin/stationctl status
    echo     3. Log:       wsl -u dev -- tail -n 80 /var/envs/run/gui.log
    pause
    exit /b 1
)

echo [*] Waiting for http://localhost:7682 ...
powershell -NoProfile -Command "$ok=$false; for ($i=0; $i -lt 40; $i++) { try { $r=[System.Net.WebRequest]::Create('http://127.0.0.1:7682/api/ping'); $r.Timeout=1200; $res=$r.GetResponse(); if($res.StatusCode -eq 200){$ok=$true; break} } catch {} Start-Sleep -Milliseconds 500 }; if (-not $ok) { exit 1 }"
if %errorlevel% neq 0 (
    echo.
    echo [!] GUI did not answer on port 7682.
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
echo [i] This window can be closed; the station keeps running in WSL.
ping -n 4 127.0.0.1 >nul
endlocal
