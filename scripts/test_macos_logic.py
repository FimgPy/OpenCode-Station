#!/usr/bin/env python3
"""Exercise macOS-specific branches of station_core on a non-Mac host.

This cannot replace a real Mac test, but it verifies the macOS path logic:
state dir, display paths, user-space isolation, ps-based process lookup and
environment lifecycle without Linux-only calls.
"""
import os
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "bin"))
import station_core as core  # noqa: E402

tmp = tempfile.mkdtemp(prefix="station-macos-")
old_home = os.environ.get("HOME")
try:
    core.PLATFORM = "macos"
    core.IS_MACOS = True
    core.IS_LINUX = False
    core.IS_WSL = False
    core.IS_WINDOWS = False

    assert core.export_root() == "", "export_root must be empty on macOS"
    assert core.to_display_path("/Users/dev/project") == "/Users/dev/project"
    assert core.to_native_path("/Users/dev/project") == "/Users/dev/project"

    os.environ["HOME"] = tmp
    state = core._default_data_dir()
    assert state.endswith(os.path.join("Library", "Application Support", "OpenCodeStation")), state

    exports = core.shell_exports("default")
    assert "ENV_ISOLATION=user" in exports, "macOS must use user-space isolation"

    # ps-based branches must not raise.
    core.find_processes(["ttyd"])
    core.find_env_pids("default")

    os.environ["OPENCODE_STATION_DATA"] = os.path.join(tmp, "state")
    core.reload_paths()
    core.ensure_manifest()
    ok, info = core.create_env("mac-check", "http://127.0.0.1:9999", True)
    assert ok, info
    home, workspace = core.env_paths("mac-check")
    assert os.path.isdir(home) and os.path.isdir(workspace)
    enabled, url, _ = core.read_proxy_config(home)
    assert enabled and url == "http://127.0.0.1:9999"
    assert core.env_info("mac-check")["hostname"].startswith("node-mac-check-")
    assert core.delete_env("mac-check")[0]

    print("[OK] macOS logic checks passed")
finally:
    if old_home is not None:
        os.environ["HOME"] = old_home
    shutil.rmtree(tmp, ignore_errors=True)
