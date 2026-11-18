#!/usr/bin/env bash
# =============================================================================
#  OpenCode Station - macOS installer
#  This file is macOS-only. Windows uses windows/setup.bat.
#  Made by Anton Kovalkin. All rights reserved.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$HERE/bin" ]; then
    ROOT="$HERE"
else
    ROOT="$(dirname "$HERE")"
fi
cd "$ROOT"

CHECK_ONLY=0
NO_DOWNLOAD=0
NO_TERMINAL=0
ASSUME_YES=0

for arg in "$@"; do
    case "$arg" in
        --check) CHECK_ONLY=1 ;;
        --no-download) NO_DOWNLOAD=1 ;;
        --no-terminal) NO_TERMINAL=1 ;;
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help)
            cat <<EOF
OpenCode Station - macOS installer

Usage: ./install.command [options]

  --check          Only verify the environment, change nothing
  --no-download    Do not download ttyd / OpenCode CLI
  --no-terminal    Do not install ttyd via Homebrew
  -y, --yes        Answer yes to optional prompts
  -h, --help       Show this help
EOF
            exit 0
            ;;
        *) echo "[!] Unknown option: $arg" >&2; exit 2 ;;
    esac
done

say() { printf '%s\n' "$*"; }
ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

say "=============================================================="
say "        OpenCode Station - macOS installer  v3.1"
say "        Made by Anton Kovalkin. All rights reserved."
say "=============================================================="

# --- 1. platform -------------------------------------------------------------
OS_NAME="$(uname -s)"
ARCH="$(uname -m)"
if [ "$OS_NAME" != "Darwin" ]; then
    if [ "${OPENCODE_STATION_ALLOW_NON_MACOS:-0}" = "1" ]; then
        warn "Non-macOS host detected ($OS_NAME/$ARCH): validation mode."
    else
        fail "This installer is for macOS only. Windows: windows/setup.bat. Linux: linux/install.sh."
    fi
else
    MACOS_VER="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
    say "[i] macOS $MACOS_VER / $ARCH"
fi

case "$ARCH" in
    arm64|x86_64) ok "Architecture: $ARCH" ;;
    *) warn "Untested architecture: $ARCH (expected arm64 or x86_64)" ;;
esac

# --- 2. tools ----------------------------------------------------------------
command -v curl >/dev/null 2>&1 || fail "curl is required (it ships with macOS)."
ok "curl found"

if ! command -v python3 >/dev/null 2>&1; then
    fail "python3 is required. Install Apple Command Line Tools: xcode-select --install"
fi
python3 - <<'PY' || fail "Python 3.8 or newer is required."
import sys
if sys.version_info < (3, 8):
    raise SystemExit(1)
print("[OK] Python", sys.version.split()[0])
PY

# Remove the quarantine flag from a downloaded archive (best effort).
if [ "$OS_NAME" = "Darwin" ] && command -v xattr >/dev/null 2>&1; then
    xattr -dr com.apple.quarantine "$ROOT" 2>/dev/null || true
fi

if [ ! -f "$ROOT/bin/station_core.py" ]; then
    fail "bin/station_core.py is missing. Unpack the macOS package completely."
fi
chmod +x "$ROOT/bin/"* 2>/dev/null || true
chmod +x "$ROOT/install.command" "$ROOT/start.command" "$ROOT/stop.command" 2>/dev/null || true
ok "Station files found"

if [ "$CHECK_ONLY" = "1" ]; then
    say ""
    say "[i] Check mode: environment looks usable."
    say "    Run ./install.command (or double-click install.command) to install."
    exit 0
fi

# --- 3. ttyd (web terminal) --------------------------------------------------
find_ttyd() {
    if [ -x "$ROOT/bin/ttyd" ]; then
        # Reject Linux/Windows binaries shipped by mistake.
        if ! file "$ROOT/bin/ttyd" 2>/dev/null | grep -q 'Mach-O'; then
            rm -f "$ROOT/bin/ttyd"
        fi
    fi
    [ -x "$ROOT/bin/ttyd" ] && { echo "$ROOT/bin/ttyd"; return; }
    command -v ttyd 2>/dev/null && return
    for cand in /opt/homebrew/bin/ttyd /usr/local/bin/ttyd; do
        [ -x "$cand" ] && { echo "$cand"; return; }
    done
    return 0
}

TTYD_BIN="$(find_ttyd || true)"
if [ -n "$TTYD_BIN" ]; then
    ok "ttyd: $TTYD_BIN"
elif [ "$NO_TERMINAL" = "1" ]; then
    warn "ttyd is not installed; the GUI will work without the embedded terminal."
elif command -v brew >/dev/null 2>&1; then
    say "[*] Installing ttyd with Homebrew..."
    if brew install ttyd >/dev/null 2>&1; then
        ok "ttyd installed: $(command -v ttyd)"
    else
        warn "brew install ttyd failed. Run it manually later."
    fi
elif [ "$ASSUME_YES" = "1" ] && [ -t 0 ]; then
    say "[*] Homebrew not found. Installing Homebrew + ttyd..."
    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
        brew install ttyd >/dev/null 2>&1 || true
    fi
    TTYD_BIN="$(find_ttyd || true)"
    if [ -n "$TTYD_BIN" ]; then ok "ttyd: $TTYD_BIN"; else warn "ttyd was not installed."; fi
else
    warn "ttyd is not installed. The GUI works, the embedded terminal will be unavailable."
    warn "Install it later:  brew install ttyd"
fi

# --- 4. OpenCode CLI ---------------------------------------------------------
if [ ! -x "$ROOT/bin/opencode-bin" ] && [ "$NO_DOWNLOAD" = "0" ]; then
    say "[*] Downloading the OpenCode CLI..."
    if curl -fsSL --max-time 180 https://opencode.ai/v2/install | bash -s -- --no-modify-path; then
        for cand in "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode /opt/homebrew/bin/opencode; do
            if [ -x "$cand" ]; then
                cp -f "$cand" "$ROOT/bin/opencode-bin"
                chmod +x "$ROOT/bin/opencode-bin"
                break
            fi
        done
    fi
fi

if [ -x "$ROOT/bin/opencode-bin" ]; then
    ok "OpenCode CLI: bin/opencode-bin"
    python3 "$ROOT/bin/patch-opencode.py" "$ROOT/bin/opencode-bin" >/dev/null 2>&1 || true
elif [ "$NO_DOWNLOAD" = "1" ]; then
    warn "OpenCode CLI not bundled (--no-download)."
else
    fail "Could not install the OpenCode CLI. Run manually:
  curl -fsSL https://opencode.ai/v2/install | bash -s -- --no-modify-path
  cp ~/.opencode/bin/opencode \"$ROOT/bin/opencode-bin\""
fi

# --- 5. state dir / manifest -------------------------------------------------
python3 - <<PY
import os, sys
sys.path.insert(0, r"$ROOT/bin")
import station_core as core
core.ensure_manifest()
print("[OK] State dir:", core.STATE_DIR)
print("[OK] Platform :", core.PLATFORM)
PY

# --- 6. optional CLI launcher ------------------------------------------------
if [ "$OS_NAME" = "Darwin" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "$ROOT/bin/stationctl" "$HOME/.local/bin/station" 2>/dev/null || true
    ok "CLI: ~/.local/bin/station"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) warn "Add to PATH:  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
    esac
fi

say ""
say "=============================================================="
say "[DONE] OpenCode Station for macOS is ready."
say ""
say "  Start (double-click) : start.command"
say "  Stop  (double-click) : stop.command"
say "  GUI                  : http://localhost:7682"
say "  Terminal             : http://localhost:7681"
say "  CLI                  : station status"
say "=============================================================="
