@echo off
chcp 65001 >nul
setlocal
title OpenCode Station - web terminal
cd /d "%~dp0"

echo ==============================================================================
echo                OpenCode Station for Windows - web terminal
echo ==============================================================================
echo.
echo [*] Starting the station...
wsl.exe -u dev -- bash -lc "python3 /usr/local/bin/stationctl start --no-browser"
if %errorlevel% neq 0 (
    echo [!] The station did not start. Run setup.bat first.
    pause
    exit /b 1
)

echo [*] Waiting for the web terminal on http://localhost:7681 ...
powershell -NoProfile -Command "$ok=$false; for ($i=0; $i -lt 40; $i++) { try { $r=[System.Net.WebRequest]::Create('http://127.0.0.1:7681/'); $r.Timeout=1200; $res=$r.GetResponse(); if($res.StatusCode -eq 200){$ok=$true; break} } catch {} Start-Sleep -Milliseconds 500 }; if (-not $ok) { exit 1 }"
if %errorlevel% neq 0 (
    echo [!] Terminal did not start. ttyd is required: run setup.bat.
    echo     Log: wsl -u dev -- tail -n 80 /var/envs/run/ttyd.log
    pause
    exit /b 1
)
start "" http://localhost:7681
echo.
echo [i] GUI is also available at http://localhost:7682
ping -n 4 127.0.0.1 >nul
endlocal
