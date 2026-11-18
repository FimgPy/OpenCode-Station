#!/usr/bin/env bash
# OpenCode Station portable installer (Linux / WSL / macOS)
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
OS="$(uname -s)"
ARCH="$(uname -m)"

say() { printf '%s\n' "$*"; }
fail() { printf '[!] %s\n' "$*" >&2; exit 1; }

say "=============================================================="
say "        OpenCode Station - portable setup"
say "        Made by Anton Kovalkin. All rights reserved."
say "=============================================================="
say "[*] OS: $OS / $ARCH"

command -v python3 >/dev/null 2>&1 || fail "python3 is required (3.8+)."
python3 - <<'PY' || fail "Python 3.8+ is required."
import sys
if sys.version_info < (3, 8):
    raise SystemExit(1)
print("[OK] Python", sys.version.split()[0])
PY

command -v curl >/dev/null 2>&1 || fail "curl is required."
if ! command -v openssl >/dev/null 2>&1; then
    say "[!] openssl not found: strict TLS proxy checks will rely on curl only."
fi

mkdir -p "$DIR/workspace" "$DIR/bin"
chmod +x "$DIR/bin/"* 2>/dev/null || true

# --- ttyd ---------------------------------------------------------------
if ! command -v ttyd >/dev/null 2>&1 && [ ! -x "$DIR/bin/ttyd" ]; then
    if [ "$OS" = "Darwin" ]; then
        say "[i] Install the web terminal: brew install ttyd"
    else
        case "$ARCH" in
            x86_64|amd64) TTYD_ASSET="ttyd.x86_64" ;;
            aarch64|arm64) TTYD_ASSET="ttyd.aarch64" ;;
            *) TTYD_ASSET="" ;;
        esac
        if [ -n "$TTYD_ASSET" ]; then
            say "[*] Downloading ttyd ($TTYD_ASSET)..."
            if curl -fsSL --max-time 60 \
                "https://github.com/tsl0922/ttyd/releases/download/1.7.7/$TTYD_ASSET" \
                -o "$DIR/bin/ttyd"; then
                chmod +x "$DIR/bin/ttyd"
                say "[OK] ttyd installed into bin/"
            else
                say "[!] Could not download ttyd. GUI will work without the embedded terminal."
                say "    Install it manually: sudo apt install ttyd (Debian/Ubuntu) or brew install ttyd (macOS)."
            fi
        fi
    fi
else
    say "[OK] ttyd found."
fi

# --- OpenCode CLI -------------------------------------------------------
if [ ! -x "$DIR/bin/opencode-bin" ]; then
    say "[*] Downloading OpenCode CLI for $OS/$ARCH..."
    if curl -fsSL --max-time 120 https://opencode.ai/v2/install | bash; then
        for cand in "$HOME/.opencode/bin/opencode" "/root/.opencode/bin/opencode"; do
            if [ -x "$cand" ]; then
                cp -f "$cand" "$DIR/bin/opencode-bin"
                chmod +x "$DIR/bin/opencode-bin"
                break
            fi
        done
    fi
fi
if [ -x "$DIR/bin/opencode-bin" ]; then
    say "[OK] OpenCode binary: bin/opencode-bin"
else
    say "[!] OpenCode binary not found. Run setup again after installing:"
    say "    curl -fsSL https://opencode.ai/v2/install | bash"
fi

# --- data dirs / manifest ----------------------------------------------
python3 - <<PY
import sys
sys.path.insert(0, r"$DIR/bin")
import station_core as core
core.ensure_manifest()
print("[OK] State dir:", core.STATE_DIR)
print("[OK] Platform :", core.PLATFORM)
PY

chmod +x "$DIR/start_gui.sh" "$DIR/stop.sh" "$DIR/bin/stationctl" "$DIR/bin/opencode" 2>/dev/null || true

say ""
say "=============================================================="
say "[DONE] OpenCode Station is ready."
say ""
say "  GUI / terminal : ./start_gui.sh"
say "  Stop           : ./stop.sh"
say "  CLI            : ./bin/env-mgr list"
say "  Proxy manager  : ./bin/proxy-tool list"
say "=============================================================="
