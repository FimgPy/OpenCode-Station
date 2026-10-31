@echo off
chcp 1251 >nul
title OpenCode Station - Остановка
echo ==============================================================================
echo                      OpenCode Station - Остановка служб
echo                      Сделано Антоном Ковалкиным все права защищены.
echo ==============================================================================
echo.
echo [*] Остановка фоновых служб OpenCode Station...
wsl.exe -u dev -- bash -c "killall -9 ttyd python3 2>/dev/null || true"
echo [+] Все службы успешно остановлены.
timeout /t 2 >nul
