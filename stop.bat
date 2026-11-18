@echo off
chcp 65001 >nul
title OpenCode Station - stop
echo ==============================================================================
echo                      OpenCode Station - stop all services
echo ==============================================================================
echo.
wsl.exe -u dev -- bash -lc "python3 /usr/local/bin/stationctl stop 2>/dev/null || (pkill -9 -f '[o]pencode-gui-server' 2>/dev/null; pkill -9 -f '[t]tyd -p 7681' 2>/dev/null; pkill -9 -f '[o]pencode-proxy-bridge' 2>/dev/null; true)"
echo [+] OpenCode Station stopped.
timeout /t 2 >nul
