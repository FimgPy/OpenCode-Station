@echo off
chcp 65001 >nul
setlocal
title OpenCode Station - Windows setup
cd /d "%~dp0"

set "HERE=%~dp0"
set "STATION_ROOT=%HERE%"
if not exist "%STATION_ROOT%bin\station_core.py" (
    for %%I in ("%HERE%..") do set "STATION_ROOT=%%~fI\"
)
cd /d "%STATION_ROOT%"

echo ==============================================================================
echo            OpenCode Station - Windows (WSL) installer  v3.1
echo            Made by Anton Kovalkin. All rights reserved.
echo ==============================================================================
echo.
echo [i] Windows version: WSL backend + native .bat launchers.
echo [i] macOS users must use the macOS package: install.command.
echo.

wsl.exe --status >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] WSL is not installed.
    echo [*] Installing WSL + Ubuntu. A reboot may be required...
    wsl.exe --install -d Ubuntu
    echo.
    echo [*] After reboot, run setup.bat again.
    pause
    exit /b 1
)
echo [1/5] WSL detected.

if not exist "%HERE%install_wsl.sh" (
    echo [!] install_wsl.sh is missing next to setup.bat. Re-download the Windows package.
    pause
    exit /b 1
)
if not exist "%STATION_ROOT%bin\station_core.py" (
    echo [!] bin\station_core.py is missing. Re-download the Windows package.
    pause
    exit /b 1
)

set "ROOT_WIN=%STATION_ROOT:\=/%"
for /f "usebackq delims=" %%i in (`wsl.exe wslpath "%ROOT_WIN%"`) do set "WSL_SRC=%%i"
set "INSTALLER_WIN=%HERE%install_wsl.sh"
set "INSTALLER_WIN=%INSTALLER_WIN:\=/%"
for /f "usebackq delims=" %%i in (`wsl.exe wslpath "%INSTALLER_WIN%"`) do set "WSL_INSTALLER=%%i"

echo [2/5] Source directory: %WSL_SRC%
echo [3/5] Installing packages, ttyd, OpenCode CLI and station files...
wsl.exe -u root -- bash "%WSL_INSTALLER%" "%WSL_SRC%"
if %errorlevel% neq 0 (
    echo [!] WSL installation failed. See the messages above.
    pause
    exit /b 1
)

echo [4/5] Preparing the Windows workspace...
set "PROJECTS_ROOT=%STATION_ROOT%workspace"
if not exist "%PROJECTS_ROOT%" mkdir "%PROJECTS_ROOT%"
if not exist "%PROJECTS_ROOT%\default" mkdir "%PROJECTS_ROOT%\default"
if not exist "%PROJECTS_ROOT%\default\README.md" (
    echo # Default environment > "%PROJECTS_ROOT%\default\README.md"
)

echo [5/5] Checking the installation...
wsl.exe -u dev -- bash -lc "python3 /usr/local/bin/station_core.py status; command -v ttyd || true; test -x /usr/local/bin/opencode-bin && echo 'opencode: OK' || echo 'opencode: missing'"

echo.
echo ==============================================================================
echo [DONE] OpenCode Station for Windows is installed.
echo.
echo   GUI / terminal : start_gui.bat   (http://localhost:7682)
echo   Web terminal   : start_web.bat   (http://localhost:7681)
echo   Console        : start.bat
echo   Stop           : stop.bat
echo ==============================================================================
pause
