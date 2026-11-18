#!/usr/bin/env bash
# Verify the two distribution packages before publishing.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
cd "$ROOT"

VERSION="$(python3 - <<'PY'
import re
for line in open('bin/station_core.py', encoding='utf-8'):
    if line.startswith('APP_VERSION'):
        print(re.split(r'["\']', line)[1])
        break
PY
)"
WIN="dist/OpenCode-Station-$VERSION-Windows.zip"
MAC="dist/OpenCode-Station-$VERSION-macOS.tar.gz"

[ -f "$WIN" ] || { echo "[!] Missing $WIN (run scripts/build_packages.sh)"; exit 1; }
[ -f "$MAC" ] || { echo "[!] Missing $MAC (run scripts/build_packages.sh)"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/windows" "$TMP/macos"

python3 - "$WIN" "$MAC" "$TMP" <<'PY'
import os, sys, tarfile, zipfile
win, mac, tmp = sys.argv[1], sys.argv[2], sys.argv[3]
zipfile.ZipFile(win).extractall(os.path.join(tmp, 'windows'))
tarfile.open(mac).extractall(os.path.join(tmp, 'macos'))
print("[OK] archives extracted")
PY

fail=0
note() { printf '%s\n' "$*"; }
must() {
    if [ -e "$1" ]; then note "  [OK] ${1#$2/}"; else note "  [MISSING] ${1#$2/}"; fail=1; fi
}
absent() {
    if [ -e "$1" ]; then note "  [WRONG PLATFORM] ${1#$2/}"; fail=1; else note "  [OK absent] ${1#$2/}"; fi
}

echo "===== Windows package ====="
must "$TMP/windows/setup.bat" "$TMP/windows"
must "$TMP/windows/install_wsl.sh" "$TMP/windows"
must "$TMP/windows/bin/station_core.py" "$TMP/windows"
must "$TMP/windows/bin/stationctl" "$TMP/windows"
must "$TMP/windows/terminal.html" "$TMP/windows"
absent "$TMP/windows/install.command" "$TMP/windows"
absent "$TMP/windows/start.command" "$TMP/windows"
absent "$TMP/windows/bin/opencode-bin" "$TMP/windows"
absent "$TMP/windows/bin/ttyd" "$TMP/windows"

bash "$TMP/windows/install_wsl.sh" --check "$TMP/windows" >/dev/null || { echo "  [FAIL] install_wsl.sh --check"; fail=1; }

echo "===== macOS package ====="
must "$TMP/macos/install.command" "$TMP/macos"
must "$TMP/macos/install.sh" "$TMP/macos"
must "$TMP/macos/start.command" "$TMP/macos"
must "$TMP/macos/stop.command" "$TMP/macos"
must "$TMP/macos/bin/station_core.py" "$TMP/macos"
must "$TMP/macos/bin/stationctl" "$TMP/macos"
absent "$TMP/macos/setup.bat" "$TMP/macos"
absent "$TMP/macos/install_wsl.sh" "$TMP/macos"
absent "$TMP/macos/bin/win-open" "$TMP/macos"
absent "$TMP/macos/bin/opencode-bin" "$TMP/macos"
absent "$TMP/macos/bin/ttyd" "$TMP/macos"

for script in "$TMP/macos/install.sh" "$TMP/macos/install.command" \
              "$TMP/macos/start.command" "$TMP/macos/stop.command"; do
    bash -n "$script" || { echo "  [FAIL] syntax: $script"; fail=1; }
done

rm -rf "$TMP/mac-state"
OPENCODE_STATION_ALLOW_NON_MACOS=1 OPENCODE_STATION_DATA="$TMP/mac-state" \
    bash "$TMP/macos/install.sh" --check >/dev/null || { echo "  [FAIL] install.sh --check"; fail=1; }

python3 - <<PY || fail=1
import compileall, sys
for base in (r"$TMP/windows/bin", r"$TMP/macos/bin"):
    if not compileall.compile_dir(base, quiet=1, force=True):
        raise SystemExit(1)
print("  [OK] Python sources compile")
PY

python3 scripts/test_macos_logic.py || fail=1

if [ "$fail" -ne 0 ]; then
    echo "[!] PACKAGE VERIFICATION FAILED"
    exit 1
fi
echo
echo "[DONE] Both packages are platform-separated and structurally valid."
