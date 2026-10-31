@echo off
chcp 1251 >nul
title OpenCode Station - Панель управления (GUI)
cd /d "%~dp0"

echo ==============================================================================
echo                      OpenCode Station - Панель управления
echo                      Сделано Антоном Ковалкиным все права защищены.
echo ==============================================================================
echo.
echo [*] Запуск служб OpenCode Station...

:: 1. Остановка старых процессов
wsl.exe -u dev -- bash -c "killall -9 ttyd python3 2>/dev/null || true"

:: 2. Запуск ttyd и сервера GUI в фоновом режиме текущей консоли
start /b "" wsl.exe -u dev -- ttyd -p 7681 -W -I /usr/local/share/ttyd/index.html -w /home/dev/workspace/default -t fontSize=14 bash
start /b "" wsl.exe -u dev -- python3 -u /usr/local/bin/opencode-gui-server

:: 3. Ожидание готовности сервера GUI
echo [*] Ожидание запуска панели управления http://localhost:7682...
powershell -NoProfile -Command "$ok=$false; for ($i=0; $i -lt 15; $i++) { try { $r=[System.Net.WebRequest]::Create('http://127.0.0.1:7682/api/ping'); $r.Timeout=1000; $res=$r.GetResponse(); if($res.StatusCode -eq 200){$ok=$true; break} } catch {} Start-Sleep -Milliseconds 600 }; if (-not $ok) { exit 1 }"
if %errorlevel% neq 0 (
    echo.
    echo [!] Ошибка запуска: сервер не ответил на порту 7682 за 15 секунд.
    pause
    exit /b 1
)

echo.
echo ==============================================================================
echo [+] ВСЕ СЛУЖБЫ УСПЕШНО ЗАПУЩЕНЫ И АКТИВНЫ!
echo     * Панель управления (GUI): http://localhost:7682
echo     * Веб-терминал:           http://localhost:7681
echo.
echo [*] Открытие панели управления в браузере...
start http://localhost:7682
echo.
echo [i] ВНИМАНИЕ: Это окно консоли поддерживает работу сервера localhost:7682.
echo     Не закрывайте его во время работы с OpenCode Station.
echo     (Для остановки сервера: просто закройте это окно или нажмите Ctrl+C).
echo ==============================================================================
echo.

powershell -NoProfile -Command "while ($true) { Start-Sleep -Seconds 3600 }"
