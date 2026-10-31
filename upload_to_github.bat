@echo off
chcp 1251 >nul
title OpenCode Station - Загрузка на GitHub (FimgPy/OpenCode-Station)
cd /d "%~dp0"

echo ==============================================================================
echo                 Загрузка проекта на GitHub (FimgPy/OpenCode-Station)
echo                 Сделано Антоном Ковалкиным все права защищены.
echo ==============================================================================
echo.

:: 1. Проверка авторизации gh в WSL
wsl.exe -e gh auth status >nul 2>&1
if %errorlevel% neq 0 (
    echo [i] Требуется однократная авторизация в GitHub.
    echo [*] Сейчас откроется страница входа с одноразовым кодом...
    echo.
    wsl.exe -e gh auth login -h github.com -p https -w
    if %errorlevel% neq 0 (
        echo.
        echo [!] Ошибка авторизации. Если вы хотите использовать токен, запустите:
        echo     wsl gh auth login --with-token
        pause
        exit /b 1
    )
)

echo.
echo [*] Создание репозитория OpenCode-Station на GitHub (если еще не создан)...
wsl.exe -e bash -c "
    cd /mnt/d/OpenCode-Station_Package
    gh repo create FimgPy/OpenCode-Station --public --description 'Автономная рабочая станция OpenCode с изолированными средами, Web GUI и менеджером прокси' 2>/dev/null || true
    git branch -M main
    git remote set-url origin https://github.com/FimgPy/OpenCode-Station.git 2>/dev/null || git remote add origin https://github.com/FimgPy/OpenCode-Station.git
    echo '[*] Отправка файлов в репозиторий (git push)...'
    git push -u origin main
"

if %errorlevel% equ 0 (
    echo.
    echo ==============================================================================
    echo [+] РЕПОЗИТОРИЙ УСПЕШНО ОПУБЛИКОВАН НА GITHUB!
    echo     Ссылка: https://github.com/FimgPy/OpenCode-Station
    echo ==============================================================================
) else (
    echo.
    echo [!] Не удалось выполнить push. Проверьте подключение к интернету или права доступа.
)

echo.
pause
