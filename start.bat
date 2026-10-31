@echo off
chcp 1251 >nul
title OpenCode Station - CMD
cd /d "%~dp0"

echo ==============================================================================
echo                      OpenCode Station - Командная строка CMD
echo                      Сделано Антоном Ковалкиным все права защищены.
echo ==============================================================================
echo.

wsl.exe -u dev -- bash -c "pgrep ttyd >/dev/null || (nohup ttyd -p 7681 -W -I /usr/local/share/ttyd/index.html -w /home/dev/workspace/default -t fontSize=14 bash >/dev/null 2>&1 &)"
wsl.exe -u dev -- bash -c "pgrep -f opencode-gui-server >/dev/null || (nohup python3 -u /usr/local/bin/opencode-gui-server >/dev/null 2>&1 &)"

wsl.exe -u dev -- bash -c "cd /home/dev/workspace/default && exec bash -i"
