@echo off
chcp 65001 >nul
title OpenCode Station - console
cd /d "%~dp0"
echo ==============================================================================
echo                      OpenCode Station - console mode
echo                      Made by Anton Kovalkin. All rights reserved.
echo ==============================================================================
echo.
wsl.exe -u dev -- bash -lc "python3 /usr/local/bin/stationctl start --no-browser >/dev/null 2>&1 || true"
wsl.exe -u dev -- bash -lc "exec /usr/local/bin/env-mgr switch default"
