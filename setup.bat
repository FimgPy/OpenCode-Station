@echo off
chcp 1251 >nul
title OpenCode Station - Óñòàíîâêà
echo ==============================================================================
echo                 OpenCode Station - Ìàñòåð àâòîìàòè÷åñêîé óñòàíîâêè
echo                 Ñäåëàíî Àíòîíîì Êîâàëêèíûì âñå ïðàâà çàùèùåíû.
echo ==============================================================================
echo.

:: 1. Ïðîâåðêà íàëè÷èÿ WSL
wsl --status >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] WSL ïîäñèñòåìà íå îáíàðóæåíà.
    echo [*] Óñòàíîâêà WSL Ubuntu (ìîæåò ïîòðåáîâàòüñÿ ïîäòâåðæäåíèå àäìèíèñòðàòîðà)...
    wsl --install -d Ubuntu
    echo.
    echo [*] Åñëè ñèñòåìà ïîïðîñèëà ïåðåçàãðóçèòü êîìïüþòåð  âûïîëíèòå ïåðåçàãðóçêó,
    echo     ïîñëå ÷åãî çàïóñòèòå setup.bat åùå ðàç.
    pause
    exit /b
)

echo [1/5] Ïðîâåðêà ïîäñèñòåìû WSL... [OK]

:: 2. Îïðåäåëåíèå öåëåâîé ïàïêè ýêñïîðòà íà Windows
set "PROJECTS_ROOT=D:\OpenCode-Station_Package\workspace"
if not exist "D:\" (
    set "PROJECTS_ROOT=C:\OpenCode-Station_Package/workspace"
)
set "TARGET_DIR=%PROJECTS_ROOT%\default"
if not exist "%PROJECTS_ROOT%" mkdir "%PROJECTS_ROOT%"
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

echo [2/5] Ïîäãîòîâêà ïàïêè ýêñïîðòà (%TARGET_DIR%)... [OK]

:: 3. Îïðåäåëåíèå ïóòè èñõîäíûõ ôàéëîâ ïàêåòà â WSL
set "CURR_DIR=%~dp0"
set "CURR_DIR=%CURR_DIR:\=/%"
for /f "usebackq delims=" %%i in (`wsl wslpath "%CURR_DIR%"`) do set "WSL_SRC=%%i"

:: 4. Óñòàíîâêà ñèñòåìíûõ çàâèñèìîñòåé, ïîëüçîâàòåëÿ dev è êîìïîíåíòîâ OpenCode
echo [3/5] Ðàçâåðòûâàíèå ïîëüçîâàòåëÿ, áèíàðíèêîâ è óòèëèò â Linux...
wsl -u root -- bash -c "
    if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
        apt-get update -y && apt-get install -y python3 curl psmisc
    fi

    if ! id -u dev >/dev/null 2>&1; then
        useradd -m -s /bin/bash dev
    fi
    mkdir -p /etc/sudoers.d
    echo 'dev ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/dev
    chmod 440 /etc/sudoers.d/dev

    mkdir -p /home/dev/workspace/default /var/envs /usr/local/bin /usr/local/share/ttyd /usr/local/share/opencode_gui /etc/profile.d

    cp -r '%WSL_SRC%/bin/'* /usr/local/bin/ 2>/dev/null || true
    chmod +x /usr/local/bin/* 2>/dev/null || true

    if [ ! -f /usr/local/bin/opencode-bin ]; then
        echo '[*] Çàãðóçêà ÿäðà OpenCode CLI...'
        curl -fsSL https://opencode.ai/v2/install | bash
        if [ -f /root/.opencode/bin/opencode ]; then
            cp /root/.opencode/bin/opencode /usr/local/bin/opencode-bin
        elif [ -f /home/dev/.opencode/bin/opencode ]; then
            cp /home/dev/.opencode/bin/opencode /usr/local/bin/opencode-bin
        fi
        chmod +x /usr/local/bin/opencode-bin 2>/dev/null || true
    fi
    python3 /usr/local/bin/patch-opencode.py /usr/local/bin/opencode-bin 2>/dev/null || true

    ln -sf /usr/local/bin/ai /usr/local/bin/ask 2>/dev/null || true
    ln -sf /usr/local/bin/cmd-tree /usr/local/bin/tree 2>/dev/null || true
    ln -sf /usr/local/bin/linux-dirs /usr/local/bin/linux 2>/dev/null || true
    ln -sf /usr/local/bin/linux-dirs /usr/local/bin/ldir 2>/dev/null || true
    ln -sf /usr/local/bin/myip /usr/local/bin/ip 2>/dev/null || true
    ln -sf /usr/local/bin/win-open /usr/local/bin/open 2>/dev/null || true
    ln -sf /usr/local/bin/export-win /usr/local/bin/export 2>/dev/null || true
    ln -sf /usr/local/bin/proxy-tool /usr/local/bin/proxy 2>/dev/null || true

    cp '%WSL_SRC%/config/cmd_mode.sh' /etc/profile.d/ 2>/dev/null || true
    chmod 644 /etc/profile.d/cmd_mode.sh

    cp '%WSL_SRC%/config/ttyd_index.html' /usr/local/share/ttyd/index.html 2>/dev/null || true
    chmod 644 /usr/local/share/ttyd/index.html

    cp '%WSL_SRC%/terminal.html' /usr/local/share/opencode_gui/index.html 2>/dev/null || true
    chmod 644 /usr/local/share/opencode_gui/index.html

    chown -R dev:dev /home/dev /var/envs /usr/local/share/opencode_gui 2>/dev/null || true
    chmod -R 775 /var/envs 2>/dev/null || true
"

echo [4/5] Íàñòðîéêà ñèñòåìíîãî ïðîôèëÿ bash è ïðîêñè-çàãðóç÷èêà...
wsl -u root -- bash -c "
    if ! grep -q 'proxy_config' /etc/bash.bashrc 2>/dev/null; then
        cat << 'EOF' >> /etc/bash.bashrc

# Automatic per-environment proxy loader
# Ñäåëàíî Àíòîíîì Êîâàëêèíûì âñå ïðàâà çàùèùåíû.
if [ -f "\$HOME/.proxy_config" ]; then
    source "\$HOME/.proxy_config"
    if [ "\$PROXY_ENABLED" = "yes" ] && [ -n "\$PROXY_URL" ]; then
        export HTTP_PROXY="\$PROXY_URL"
        export HTTPS_PROXY="\$PROXY_URL"
        export http_proxy="\$PROXY_URL"
        export https_proxy="\$PROXY_URL"
        export ALL_PROXY="\$PROXY_URL"
        export all_proxy="\$PROXY_URL"
    else
        unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy
    fi
fi
export NO_PROXY="localhost,127.0.0.1,::1,local.home\${NO_PROXY:+,}\${NO_PROXY}"
export no_proxy="localhost,127.0.0.1,::1,local.home\${no_proxy:+,}\${no_proxy}"
EOF
    fi

    if ! grep -q 'cmd_mode.sh' /home/dev/.bashrc 2>/dev/null; then
        echo 'if [ -f /etc/profile.d/cmd_mode.sh ]; then . /etc/profile.d/cmd_mode.sh; fi' >> /home/dev/.bashrc
    fi
"

echo [5/5] Ïîäãîòîâêà èçîëèðîâàííîé ðàáî÷åé ñðåäû...
wsl -u dev -- bash -c "
    mkdir -p /home/dev/workspace/default
    if [ ! -f /home/dev/workspace/default/README.md ]; then
        echo '# Ñðåäà: default (Linux Ext4)' > /home/dev/workspace/default/README.md
        echo '* Ïàïêà Linux: /home/dev/workspace/default' >> /home/dev/workspace/default/README.md
        echo '* Ýêñïîðò íà äèñê Windows: %TARGET_DIR%' >> /home/dev/workspace/default/README.md
        echo '* Ñäåëàíî Àíòîíîì Êîâàëêèíûì âñå ïðàâà çàùèùåíû.' >> /home/dev/workspace/default/README.md
    fi
"

if not exist "%TARGET_DIR%\README.md" (
    copy "%~dp0workspace\*" "%TARGET_DIR%\" >nul 2>&1
)

echo.
echo ==============================================================================
echo [ÓÑÏÅÕ] OpenCode Station óñïåøíî ðàçâåðíóòà è ãîòîâà ê ðàáîòå!
echo.
echo  * Çàïóñê Ïàíåëè óïðàâëåíèÿ (GUI)     : çàïóñòèòå start_gui.bat
echo  * Çàïóñê â áðàóçåðå (Âåá-òåðìèíàë)   : çàïóñòèòå start_web.bat
echo  * Çàïóñê â Windows êîíñîëè           : çàïóñòèòå start.bat
echo  * Ïàïêà ñðåäû default íà Windows     : %TARGET_DIR%
echo.
echo  Ñäåëàíî Àíòîíîì Êîâàëêèíûì âñå ïðàâà çàùèùåíû.
echo ==============================================================================
echo.
pause
