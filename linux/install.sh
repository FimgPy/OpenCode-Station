#!/usr/bin/env bash
# =============================================================================
#  OpenCode Station - Linux installer
#  This file is Linux-only. Windows uses windows/setup.bat,
#  macOS uses macos/install.sh.
#  Made by Anton Kovalkin. All rights reserved.
# =============================================================================
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$HERE/bin" ]; then
    ROOT="$HERE"
else
    ROOT="$(dirname "$HERE")"
fi
cd "$ROOT"
ARCH="$(uname -m)"

say() { printf '%s\n' "$*"; }
fail() { printf '[!] %s\n' "$*" >&2; exit 1; }

say "=============================================================="
say "        OpenCode Station - Linux installer  v3.1"
say "        Made by Anton Kovalkin. All rights reserved."
say "=============================================================="
say "[*] Linux / $ARCH"

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

if [ ! -f "$ROOT/bin/station_core.py" ]; then
    fail "bin/station_core.py is missing. Unpack the Linux package completely."
fi

mkdir -p "$ROOT/workspace"
chmod +x "$ROOT/bin/"* 2>/dev/null || true

# --- ttyd ---------------------------------------------------------------
if ! command -v ttyd >/dev/null 2>&1 && [ ! -x "$ROOT/bin/ttyd" ]; then
    case "$ARCH" in
        x86_64|amd64) TTYD_ASSET="ttyd.x86_64" ;;
        aarch64|arm64) TTYD_ASSET="ttyd.aarch64" ;;
        *) TTYD_ASSET="" ;;
    esac
    if [ -n "$TTYD_ASSET" ]; then
        say "[*] Downloading ttyd ($TTYD_ASSET)..."
        if curl -fsSL --max-time 60 \
            "https://github.com/tsl0922/ttyd/releases/download/1.7.7/$TTYD_ASSET" \
            -o "$ROOT/bin/ttyd"; then
            chmod +x "$ROOT/bin/ttyd"
            say "[OK] ttyd installed into bin/"
        else
            say "[!] Could not download ttyd. The GUI will work without the embedded terminal."
            say "    Install manually: sudo apt install ttyd (Debian/Ubuntu)."
        fi
    fi
else
    say "[OK] ttyd found."
fi

# --- OpenCode CLI -------------------------------------------------------
if [ ! -x "$ROOT/bin/opencode-bin" ]; then
    say "[*] Downloading OpenCode CLI for Linux/$ARCH..."
    if curl -fsSL --max-time 180 https://opencode.ai/v2/install | bash -s -- --no-modify-path; then
        for cand in "$HOME/.opencode/bin/opencode" "/root/.opencode/bin/opencode"; do
            if [ -x "$cand" ]; then
                cp -f "$cand" "$ROOT/bin/opencode-bin"
                chmod +x "$ROOT/bin/opencode-bin"
                break
            fi
        done
    fi
fi
if [ -x "$ROOT/bin/opencode-bin" ]; then
    say "[OK] OpenCode binary: bin/opencode-bin"
    python3 "$ROOT/bin/patch-opencode.py" "$ROOT/bin/opencode-bin" >/dev/null 2>&1 || true
else
    say "[!] OpenCode binary not found. Run setup again after installing:"
    say "    curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path"
fi

# --- data dirs / manifest ----------------------------------------------
python3 - <<PY
import sys
sys.path.insert(0, r"$ROOT/bin")
import station_core as core
core.ensure_manifest()
print("[OK] State dir:", core.STATE_DIR)
print("[OK] Platform :", core.PLATFORM)
PY

chmod +x "$ROOT/linux/start.sh" "$ROOT/linux/stop.sh" 2>/dev/null || true

say ""
say "=============================================================="
say "[DONE] OpenCode Station for Linux is ready."
say ""
say "  GUI / terminal : ./linux/start.sh"
say "  Stop           : ./linux/stop.sh"
say "  CLI            : ./bin/env-mgr list"
say "  Proxy manager  : ./bin/proxy-tool list"
say "=============================================================="
