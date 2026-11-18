#!/usr/bin/env bash
# WSL installer for OpenCode Station (invoked by setup.bat as root).
set -euo pipefail

SRC="${1:-/mnt/d/OpenCode-Station_Package}"
if [ ! -d "$SRC/bin" ]; then
    echo "[!] Source directory not found: $SRC" >&2
    exit 1
fi

echo "[1/6] Installing system packages..."
if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y python3 curl ca-certificates util-linux psmisc openssl >/dev/null 2>&1 || true
fi

if ! command -v ttyd >/dev/null 2>&1 && [ ! -x /usr/local/bin/ttyd ]; then
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64) asset="ttyd.x86_64" ;;
        aarch64|arm64) asset="ttyd.aarch64" ;;
        *) asset="" ;;
    esac
    if [ -n "$asset" ]; then
        echo "[2/6] Downloading ttyd ($asset)..."
        if curl -fsSL --max-time 90 \
            "https://github.com/tsl0922/ttyd/releases/download/1.7.7/$asset" \
            -o /usr/local/bin/ttyd; then
            chmod +x /usr/local/bin/ttyd
        fi
    fi
else
    echo "[2/6] ttyd already present."
fi

echo "[3/6] Preparing user and directories..."
if ! id -u dev >/dev/null 2>&1; then
    useradd -m -s /bin/bash dev
fi
mkdir -p /etc/sudoers.d
echo 'dev ALL=(ALL) NOPASSWD:SETENV:ALL' > /etc/sudoers.d/dev
chmod 440 /etc/sudoers.d/dev
mkdir -p /home/dev/workspace/default /var/envs /usr/local/bin \
         /usr/local/config /usr/local/share/ttyd /usr/local/share/opencode_gui

echo "[4/6] Copying OpenCode Station files..."
for f in "$SRC"/bin/*; do
    b="$(basename "$f")"
    [ "$b" = "__pycache__" ] && continue
    [ -d "$f" ] && continue
    if [ "$b" = "opencode-bin" ] && [ -x /usr/local/bin/opencode-bin ]; then
        continue
    fi
    cp -f "$f" "/usr/local/bin/$b"
done
chmod +x /usr/local/bin/* 2>/dev/null || true

cp -f "$SRC/terminal.html" /usr/local/terminal.html
cp -f "$SRC/terminal.html" /usr/local/share/opencode_gui/index.html
cp -f "$SRC/config/"*.sh /usr/local/config/ 2>/dev/null || true
cp -f "$SRC/config/proxies_catalog.json" /usr/local/config/ 2>/dev/null || true
cp -f "$SRC/config/ttyd_index.html" /usr/local/share/ttyd/index.html
cp -f "$SRC/config/ttyd_index.html" /usr/local/config/ttyd_index.html 2>/dev/null || true
chmod 644 /usr/local/terminal.html /usr/local/share/opencode_gui/index.html \
           /usr/local/share/ttyd/index.html 2>/dev/null || true

# Profile scripts keep the legacy CMD mode working in WSL only.
cp -f "$SRC/config/cmd_mode.sh" /etc/profile.d/cmd_mode.sh
cp -f "$SRC/config/00-opencode-init.sh" /etc/profile.d/00-opencode-init.sh
chmod 644 /etc/profile.d/cmd_mode.sh
chmod 755 /etc/profile.d/00-opencode-init.sh

if [ -f "$SRC/config/proxies_catalog.json" ]; then
    cp -f "$SRC/config/proxies_catalog.json" /var/envs/proxies_catalog.json
fi
if [ ! -f /var/envs/global_proxy.json ]; then
    echo '{"enabled": false, "url": ""}' > /var/envs/global_proxy.json
fi

# OpenCode CLI (download only when missing).
if [ ! -x /usr/local/bin/opencode-bin ]; then
    echo "[*] Downloading OpenCode CLI..."
    if curl -fsSL https://opencode.ai/v2/install | bash; then
        for cand in /root/.opencode/bin/opencode /home/dev/.opencode/bin/opencode; do
            if [ -x "$cand" ]; then
                cp -f "$cand" /usr/local/bin/opencode-bin
                chmod +x /usr/local/bin/opencode-bin
                break
            fi
        done
    fi
fi
python3 /usr/local/bin/patch-opencode.py /usr/local/bin/opencode-bin >/dev/null 2>&1 || true

ln -sf /usr/local/bin/ai /usr/local/bin/ask 2>/dev/null || true
ln -sf /usr/local/bin/cmd-tree /usr/local/bin/tree 2>/dev/null || true
ln -sf /usr/local/bin/linux-dirs /usr/local/bin/linux 2>/dev/null || true
ln -sf /usr/local/bin/linux-dirs /usr/local/bin/ldir 2>/dev/null || true
# /usr/local/bin/ip used to shadow the real iproute2 utility with myip.
rm -f /usr/local/bin/ip 2>/dev/null || true
ln -sf /usr/local/bin/win-open /usr/local/bin/open 2>/dev/null || true
ln -sf /usr/local/bin/export-win /usr/local/bin/export 2>/dev/null || true
ln -sf /usr/local/bin/proxy-tool /usr/local/bin/proxy 2>/dev/null || true

# Legacy user profile (do not destroy a customized one).
if [ ! -f /home/dev/.bashrc ] && [ -f "$SRC/config/bashrc_template" ]; then
    cp -f "$SRC/config/bashrc_template" /home/dev/.bashrc
fi
if ! grep -q '00-opencode-init.sh' /etc/bash.bashrc 2>/dev/null; then
    echo 'if [ -f /etc/profile.d/00-opencode-init.sh ]; then . /etc/profile.d/00-opencode-init.sh; fi' >> /etc/bash.bashrc
fi

echo "[5/6] Fixing permissions..."
chown -R dev:dev /home/dev /var/envs /usr/local/share/opencode_gui 2>/dev/null || true
chmod -R 775 /var/envs 2>/dev/null || true
chown dev:dev /usr/local/terminal.html 2>/dev/null || true

echo "[6/6] Initializing manifest..."
python3 /usr/local/bin/station_core.py status >/dev/null 2>&1 || true
mkdir -p /home/dev/workspace/default
if [ ! -f /home/dev/workspace/default/README.md ]; then
    printf '# Default environment\n* Linux: /home/dev/workspace/default\n* Windows export: %s\\workspace\\default\n' "$SRC" > /home/dev/workspace/default/README.md
fi
chown -R dev:dev /home/dev/workspace/default 2>/dev/null || true

echo "[OK] WSL part installed."
