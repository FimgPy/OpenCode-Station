@echo off
chcp 65001 >nul
setlocal
title OpenCode Station - web terminal
cd /d "%~dp0"

echo ==============================================================================
echo                      OpenCode Station - web terminal
echo ==============================================================================
echo.
wsl.exe -u dev -- bash -lc "python3 /usr/local/bin/stationctl stop >/dev/null 2>&1 || true"
start "" /b wsl.exe -u dev -- bash -lc "python3 -u /usr/local/bin/opencode-gui-server --port 7682"

echo [*] Waiting for the web terminal on http://localhost:7681 ...
powershell -NoProfile -Command "$ok=$false; for ($i=0; $i -lt 40; $i++) { try { $r=[System.Net.WebRequest]::Create('http://127.0.0.1:7681/'); $r.Timeout=1200; $res=$r.GetResponse(); if($res.StatusCode -eq 200){$ok=$true; break} } catch {} Start-Sleep -Milliseconds 500 }; if (-not $ok) { exit 1 }"
if %errorlevel% neq 0 (
    echo [!] Terminal did not start. Run setup.bat (ttyd is required).
    pause
    exit /b 1
)
start "" http://localhost:7681
echo.
echo [i] GUI is also available at http://localhost:7682
timeout /t 3 >nul
endlocal
