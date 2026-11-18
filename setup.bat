@echo off
chcp 65001 >nul
setlocal
title OpenCode Station - setup
cd /d "%~dp0"

echo ==============================================================================
echo                 OpenCode Station - Windows / WSL setup
echo                 Made by Anton Kovalkin. All rights reserved.
echo ==============================================================================
echo.

wsl.exe --status >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] WSL is not installed.
    echo [*] Installing WSL + Ubuntu (a reboot may be required)...
    wsl.exe --install -d Ubuntu
    echo.
    echo [*] After reboot, run setup.bat again.
    pause
    exit /b
)
echo [1/5] WSL detected.

set "CURR_DIR=%~dp0"
set "CURR_DIR=%CURR_DIR:\=/%"
for /f "usebackq delims=" %%i in (`wsl.exe wslpath "%CURR_DIR%"`) do set "WSL_SRC=%%i"

echo [2/5] Source directory: %WSL_SRC%
if not exist "%CURR_DIR%config\install_wsl.sh" (
    echo [!] config\install_wsl.sh is missing. Re-download the repository.
    pause
    exit /b 1
)

echo [3/5] Installing packages, ttyd, OpenCode CLI and station files...
wsl.exe -u root -- bash "%WSL_SRC%/config/install_wsl.sh" "%WSL_SRC%"
if %errorlevel% neq 0 (
    echo [!] WSL installation failed. See the messages above.
    pause
    exit /b 1
)

echo [4/5] Preparing the Windows workspace...
set "PROJECTS_ROOT=%CURR_DIR%workspace"
if not exist "%PROJECTS_ROOT%" mkdir "%PROJECTS_ROOT%"
if not exist "%PROJECTS_ROOT%\default" mkdir "%PROJECTS_ROOT%\default"
if not exist "%PROJECTS_ROOT%\default\README.md" (
    echo # Default environment > "%PROJECTS_ROOT%\default\README.md"
)

echo [5/5] Checking the installation...
wsl.exe -u dev -- bash -lc "python3 /usr/local/bin/station_core.py status; command -v ttyd || true; test -x /usr/local/bin/opencode-bin && echo 'opencode: OK' || echo 'opencode: missing'"

echo.
echo ==============================================================================
echo [DONE] OpenCode Station is installed.
echo.
echo   GUI / terminal : start_gui.bat   (http://localhost:7682)
echo   Web terminal   : start_web.bat   (http://localhost:7681)
echo   Console        : start.bat
echo   Stop           : stop.bat
echo.
echo   Linux / macOS: run ./setup.sh and ./start_gui.sh
echo ==============================================================================
pause
