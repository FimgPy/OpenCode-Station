@echo off
chcp 1251 >nul
title OpenCode Station - Синхронизация с GitHub (FimgPy/OpenCode-Station)
cd /d "%~dp0"

echo ==============================================================================
echo                 Синхронизация проекта с GitHub (FimgPy/OpenCode-Station)
echo                 Сделано Антоном Ковалкиным все права защищены.
echo ==============================================================================
echo.

wsl.exe -e bash -c "cd /mnt/d/OpenCode-Station_Package && git add -A && (git commit -m 'Update' 2>/dev/null || true) && git push origin main"

if %errorlevel% equ 0 (
    echo.
    echo ==============================================================================
    echo [+] РЕПОЗИТОРИЙ УСПЕШНО СИНХРОНИЗИРОВАН!
    echo     Ссылка: https://github.com/FimgPy/OpenCode-Station
    echo ==============================================================================
) else (
    echo.
    echo [!] Ошибка отправки. Проверьте подключение к сети.
)

echo.
pause
