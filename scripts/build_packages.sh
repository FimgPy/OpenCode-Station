#!/usr/bin/env bash
# Build two independent distribution packages:
#   dist/OpenCode-Station-<ver>-Windows.zip
#   dist/OpenCode-Station-<ver>-macOS.tar.gz
# Shared engine (bin/, config/, terminal.html) is copied into both,
# but installers and launchers are platform-specific.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
cd "$ROOT"
mkdir -p dist

python3 - <<'PY'
import hashlib
import os
import shutil
import stat
import sys
import tarfile
import zipfile

ROOT = os.getcwd()
VERSION = None
core_path = os.path.join(ROOT, "bin", "station_core.py")
with open(core_path, encoding="utf-8") as fh:
    for line in fh:
        if line.startswith("APP_VERSION"):
            VERSION = line.split("=", 1)[1].strip().strip('"')
            break
VERSION = VERSION or "3.1.0"

EXCLUDE_NAMES = {"__pycache__", "opencode-bin", "opencode-bin.bak", "ttyd",
                 ".DS_Store", "Thumbs.db"}
WIN_ONLY = {"win-open", "win-path", "win-guide", "export-win"}


def engine_files(platform):
    for base, dirs, files in os.walk(os.path.join(ROOT, "bin")):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_NAMES]
        for name in files:
            if name in EXCLUDE_NAMES or name.endswith((".pyc", ".pyo", ".bak")):
                continue
            if platform == "macos" and name in WIN_ONLY:
                continue
            src = os.path.join(base, name)
            rel = os.path.relpath(src, ROOT)
            yield src, rel


def engine_extra():
    for rel in ("terminal.html", "LICENSE", "config/proxies_catalog.json",
                "config/cmd_mode.sh", "config/00-opencode-init.sh",
                "config/bashrc_template", "config/ttyd_index.html"):
        src = os.path.join(ROOT, rel)
        if os.path.isfile(src):
            yield src, rel


def is_exec(rel):
    name = os.path.basename(rel)
    return (rel.startswith("bin/") or name.endswith((".sh", ".command", ".py")))


def stage(platform):
    files = []
    if platform == "windows":
        platform_dir = os.path.join(ROOT, "windows")
        platform_files = ["setup.bat", "start_gui.bat", "start_web.bat",
                          "start.bat", "stop.bat", "install_wsl.sh"]
        readme = os.path.join(platform_dir, "README.md")
    else:
        platform_dir = os.path.join(ROOT, "macos")
        platform_files = ["install.command", "start.command", "stop.command",
                          "install.sh"]
        readme = os.path.join(platform_dir, "README.md")
    for name in platform_files:
        src = os.path.join(platform_dir, name)
        if not os.path.isfile(src):
            raise SystemExit(f"missing platform file: {src}")
        files.append((src, name))
    files.append((readme, "README.md"))
    files.extend(engine_files(platform))
    files.extend(engine_extra())
    return files


def build_zip(platform, out):
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for src, rel in stage(platform):
            info = zipfile.ZipInfo(rel.replace(os.sep, "/"))
            info.compress_type = zipfile.ZIP_DEFLATED
            mode = 0o755 if is_exec(rel) else 0o644
            info.external_attr = (mode & 0xFFFF) << 16
            with open(src, "rb") as fh:
                zf.writestr(info, fh.read())


def build_tar(platform, out):
    with tarfile.open(out, "w:gz") as tf:
        for src, rel in stage(platform):
            info = tf.gettarinfo(src, arcname=rel.replace(os.sep, "/"))
            info.mode = 0o755 if is_exec(rel) else 0o644
            with open(src, "rb") as fh:
                tf.addfile(info, fh)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


dist = os.path.join(ROOT, "dist")
win = os.path.join(dist, f"OpenCode-Station-{VERSION}-Windows.zip")
mac = os.path.join(dist, f"OpenCode-Station-{VERSION}-macOS.tar.gz")
build_zip("windows", win)
build_tar("macos", mac)

print(f"[OK] Windows package: {win} ({os.path.getsize(win)} bytes)")
print(f"     sha256 {sha256(win)}")
print(f"[OK] macOS package  : {mac} ({os.path.getsize(mac)} bytes)")
print(f"     sha256 {sha256(mac)}")

with open(os.path.join(dist, "SHA256SUMS"), "w", encoding="utf-8") as fh:
    fh.write(f"{sha256(win)}  {os.path.basename(win)}\n")
    fh.write(f"{sha256(mac)}  {os.path.basename(mac)}\n")
print("[OK] dist/SHA256SUMS")
PY
