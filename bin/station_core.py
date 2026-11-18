#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OpenCode Station portable core.

Single source of truth for paths, environments, proxies, provider config,
sessions and process management.  The module intentionally uses only the
Python standard library so it works on Linux, WSL, macOS and (for the GUI
portion) native Windows.

Made by Anton Kovalkin. All rights reserved.
"""
from __future__ import annotations

import datetime
import json
import os
import platform as _platform
import re
import shlex
import shutil
import signal
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid
import zlib
from typing import Any, Dict, Iterable, List, Optional, Tuple

APP_NAME = "OpenCode Station"
APP_VERSION = "3.0.0"
DEFAULT_NO_PROXY = "127.0.0.1,localhost,::1,local.home"

# ---------------------------------------------------------------------------
# Platform & portable paths
# ---------------------------------------------------------------------------

def _read_text(path: str) -> str:
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            return fh.read()
    except Exception:
        return ""


def is_wsl() -> bool:
    if os.name == "nt" or sys.platform == "darwin":
        return False
    return ("microsoft" in _platform.release().lower()
            or "microsoft" in _read_text("/proc/version").lower()
            or bool(os.environ.get("WSL_DISTRO_NAME")))


def is_wsl1() -> bool:
    """WSL1 has no mount/UTS namespaces and no TUN; isolation must be user-space."""
    if not is_wsl():
        return False
    release = _platform.release().lower()
    if release.startswith("4.4."):
        return True
    return not os.path.exists("/dev/vsock")


def platform_name() -> str:
    if os.name == "nt":
        return "windows"
    if sys.platform == "darwin":
        return "macos"
    if is_wsl():
        return "wsl"
    return "linux"


PLATFORM = platform_name()
IS_WINDOWS = PLATFORM == "windows"
IS_MACOS = PLATFORM == "macos"
IS_LINUX = PLATFORM in ("linux", "wsl")
IS_WSL = PLATFORM == "wsl"

STATION_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATION_ROOT = os.environ.get("OPENCODE_STATION_ROOT", STATION_ROOT)
BIN_DIR = os.path.join(STATION_ROOT, "bin")
CONFIG_DIR = os.path.join(STATION_ROOT, "config")
SHARE_DIR = os.path.join(STATION_ROOT, "share")


def _workspace_root() -> str:
    explicit = (os.environ.get("OPENCODE_STATION_WORKSPACE") or "").strip()
    if explicit:
        return os.path.abspath(os.path.expanduser(explicit))
    for candidate in ("/mnt/d/OpenCode-Station_Package/workspace",
                      "/mnt/c/OpenCode-Station_Package/workspace"):
        if os.path.isdir(candidate):
            return candidate
    return os.path.join(STATION_ROOT, "workspace")


WINDOWS_WORKSPACE_ROOT = _workspace_root()


def _writable_dir(path: str) -> bool:
    try:
        os.makedirs(path, exist_ok=True)
        probe = os.path.join(path, f".write-probe-{os.getpid()}")
        with open(probe, "w", encoding="utf-8") as fh:
            fh.write("ok")
        os.remove(probe)
        return True
    except Exception:
        return False


def _default_data_dir() -> str:
    explicit = (os.environ.get("OPENCODE_STATION_DATA") or "").strip()
    if explicit:
        return os.path.abspath(os.path.expanduser(explicit))

    # Backwards compatibility: an already provisioned WSL station keeps
    # using /var/envs.  New installations never need root.
    if IS_LINUX and os.path.exists("/var/envs/manifest.json") and _writable_dir("/var/envs"):
        return "/var/envs"

    if IS_WINDOWS:
        base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~\\AppData\\Local")
        return os.path.join(base, "OpenCodeStation")
    if IS_MACOS:
        return os.path.expanduser("~/Library/Application Support/OpenCodeStation")
    xdg = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(xdg, "opencode-station")


STATE_DIR = _default_data_dir()
LEGACY_LAYOUT = os.path.abspath(STATE_DIR) == "/var/envs"
ENVS_DIR = STATE_DIR if LEGACY_LAYOUT else os.path.join(STATE_DIR, "environments")
MANIFEST_FILE = os.path.join(STATE_DIR, "manifest.json")
GLOBAL_PROXY_FILE = os.path.join(STATE_DIR, "global_proxy.json")
PROVIDER_CONFIG_FILE = os.path.join(STATE_DIR, "provider_config.json")
CATALOG_FILE = os.path.join(STATE_DIR, "proxies_catalog.json")
PACKAGE_CATALOG_FILE = os.path.join(CONFIG_DIR, "proxies_catalog.json")
RUN_DIR = os.path.join(STATE_DIR, "run")

for _d in (STATE_DIR, ENVS_DIR, RUN_DIR):
    try:
        os.makedirs(_d, exist_ok=True)
    except Exception:
        pass


def reload_paths() -> None:
    """Re-read OPENCODE_STATION_DATA (used by tests and by installers)."""
    global STATE_DIR, LEGACY_LAYOUT, ENVS_DIR, MANIFEST_FILE, GLOBAL_PROXY_FILE
    global PROVIDER_CONFIG_FILE, CATALOG_FILE, RUN_DIR
    STATE_DIR = _default_data_dir()
    LEGACY_LAYOUT = os.path.abspath(STATE_DIR) == "/var/envs"
    ENVS_DIR = STATE_DIR if LEGACY_LAYOUT else os.path.join(STATE_DIR, "environments")
    MANIFEST_FILE = os.path.join(STATE_DIR, "manifest.json")
    GLOBAL_PROXY_FILE = os.path.join(STATE_DIR, "global_proxy.json")
    PROVIDER_CONFIG_FILE = os.path.join(STATE_DIR, "provider_config.json")
    CATALOG_FILE = os.path.join(STATE_DIR, "proxies_catalog.json")
    RUN_DIR = os.path.join(STATE_DIR, "run")
    for _d in (STATE_DIR, ENVS_DIR, RUN_DIR):
        os.makedirs(_d, exist_ok=True)


def env_dir(name: str) -> str:
    return os.path.join(ENVS_DIR, name)


def default_env_home() -> str:
    if LEGACY_LAYOUT:
        # The original WSL station used the real dev home for "default".
        return "/home/dev" if os.path.isdir("/home/dev") else os.path.expanduser("~")
    return os.path.join(env_dir("default"), "home")


def default_env_workspace() -> str:
    if LEGACY_LAYOUT:
        return "/home/dev/workspace/default"
    return os.path.join(env_dir("default"), "workspace")


def export_root() -> str:
    """Optional directory visible from the host OS (D:\\...\\workspace)."""
    if _writable_dir(WINDOWS_WORKSPACE_ROOT):
        return WINDOWS_WORKSPACE_ROOT
    return ""


def _now() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


# ---------------------------------------------------------------------------
# JSON helpers
# ---------------------------------------------------------------------------

def read_json(path: str, default: Any = None) -> Any:
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return default


def write_json(path: str, data: Any) -> bool:
    try:
        os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        tmp = f"{path}.tmp.{os.getpid()}"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
        os.replace(tmp, path)
        return True
    except Exception:
        try:
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(data, fh, indent=2, ensure_ascii=False)
            return True
        except Exception:
            return False


# ---------------------------------------------------------------------------
# Manifest / environments
# ---------------------------------------------------------------------------

def ensure_env_identity_files(name: str, mid: Optional[str] = None,
                              hostname: Optional[str] = None) -> Tuple[str, str]:
    meta_dir = env_dir(name)
    os.makedirs(meta_dir, exist_ok=True)
    mid_file = os.path.join(meta_dir, "machine-id")
    host_file = os.path.join(meta_dir, "hostname")

    if not mid:
        mid = _read_text(mid_file).strip()
        if not mid:
            mid = uuid.uuid4().hex
    with open(mid_file, "w", encoding="utf-8") as fh:
        fh.write(mid + "\n")

    if not hostname:
        hostname = _read_text(host_file).strip()
        if not hostname:
            hostname = f"node-{name}-{uuid.uuid4().hex[:4]}"
    with open(host_file, "w", encoding="utf-8") as fh:
        fh.write(hostname + "\n")
    return mid, hostname


def ensure_manifest() -> Dict[str, Any]:
    os.makedirs(ENVS_DIR, exist_ok=True)
    if not os.path.exists(MANIFEST_FILE):
        mid, host = ensure_env_identity_files("default")
        data = {
            "active": "default",
            "environments": {
                "default": {
                    "name": "default",
                    "hostname": host,
                    "machine_id": mid,
                    "home": default_env_home(),
                    "workspace": default_env_workspace(),
                    "workspace_win": to_display_path(default_env_workspace()),
                    "proxy_url": "",
                    "proxy_enabled": False,
                    "created_at": _now(),
                    "description": "Основная среда по умолчанию",
                }
            },
            "global_proxy": {"enabled": False, "url": ""},
        }
        write_json(MANIFEST_FILE, data)
        return data

    data = read_json(MANIFEST_FILE, None)
    if not isinstance(data, dict):
        data = {"active": "default", "environments": {}}
    changed = False
    envs = data.get("environments")
    if not isinstance(envs, dict):
        envs = {}
        data["environments"] = envs
        changed = True

    if "global_proxy" not in data:
        data["global_proxy"] = {"enabled": False, "url": ""}
        changed = True

    for name, info in list(envs.items()):
        if not isinstance(info, dict):
            info = {"name": name}
            envs[name] = info
            changed = True
        for key, value in (("name", name), ("hostname", f"node-{name}-0000"),
                           ("machine_id", uuid.uuid4().hex),
                           ("home", os.path.join(env_dir(name), "home")),
                           ("workspace", os.path.join(env_dir(name), "workspace")),
                           ("proxy_url", ""), ("proxy_enabled", False),
                           ("created_at", _now()), ("description", "")):
            if key not in info:
                info[key] = value
                changed = True
        if not info.get("workspace_win"):
            info["workspace_win"] = to_display_path(info.get("workspace", ""))
            changed = True

    if "default" not in envs:
        mid, host = ensure_env_identity_files("default")
        envs["default"] = {
            "name": "default",
            "hostname": host,
            "machine_id": mid,
            "home": default_env_home(),
            "workspace": default_env_workspace(),
            "workspace_win": to_display_path(default_env_workspace()),
            "proxy_url": "",
            "proxy_enabled": False,
            "created_at": _now(),
            "description": "Основная среда по умолчанию",
        }
        changed = True

    if data.get("active") not in envs:
        data["active"] = "default"
        changed = True

    if changed:
        write_json(MANIFEST_FILE, data)
    return data


def save_manifest(data: Dict[str, Any]) -> bool:
    return write_json(MANIFEST_FILE, data)


def get_active_env_name() -> str:
    forced = os.environ.get("OPENCODE_ENV", "").strip()
    if forced:
        return forced
    return str(ensure_manifest().get("active", "default"))


def env_info(name: Optional[str] = None) -> Dict[str, Any]:
    data = ensure_manifest()
    target = name or data.get("active", "default")
    return data.get("environments", {}).get(target, {})


def env_paths(name: Optional[str] = None) -> Tuple[str, str]:
    target = name or get_active_env_name()
    info = env_info(target)
    home = info.get("home") or (os.path.join(env_dir(target), "home") if target != "default" else default_env_home())
    workspace = info.get("workspace") or (os.path.join(env_dir(target), "workspace") if target != "default" else default_env_workspace())
    return home, workspace


def _write_env_bashrc(name: str, home: str, workspace: str) -> None:
    os.makedirs(home, exist_ok=True)
    data_dir = STATE_DIR
    init = os.path.join(CONFIG_DIR, "00-opencode-init.sh")
    cmd_mode = os.path.join(CONFIG_DIR, "cmd_mode.sh")
    content = f"""# OpenCode Station environment: {name}
export OPENCODE_ENV={shlex.quote(name)}
export OPENCODE_STATION_ROOT={shlex.quote(STATION_ROOT)}
export OPENCODE_STATION_DATA={shlex.quote(data_dir)}
export HOME={shlex.quote(home)}
export OPENCODE_TEST_HOME={shlex.quote(home)}
export XDG_DATA_HOME={shlex.quote(os.path.join(home, ".local", "share"))}
export XDG_CONFIG_HOME={shlex.quote(os.path.join(home, ".config"))}
export XDG_STATE_HOME={shlex.quote(os.path.join(home, ".local", "state"))}
export XDG_CACHE_HOME={shlex.quote(os.path.join(home, ".cache"))}
export NO_PROXY={shlex.quote(DEFAULT_NO_PROXY)}
export no_proxy={shlex.quote(DEFAULT_NO_PROXY)}
if [ -f {shlex.quote(init)} ]; then . {shlex.quote(init)}; fi
if [ -f {shlex.quote(cmd_mode)} ]; then . {shlex.quote(cmd_mode)}; fi
cd {shlex.quote(workspace)} 2>/dev/null || true
"""
    with open(os.path.join(home, ".bashrc"), "w", encoding="utf-8") as fh:
        fh.write(content)


def generate_random_name(existing: Iterable[str]) -> str:
    names = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta",
             "theta", "omega", "nexus", "prism", "orbit", "quantum", "stellar",
             "matrix", "vector", "phoenix", "titan", "aurora", "nova", "cyber",
             "shadow", "vortex", "zenith"]
    existing = list(existing)
    candidates = [n for n in names if not any(e == n or e.startswith(n + "-") for e in existing)]
    if candidates:
        return f"{__import__('random').choice(candidates)}-{__import__('random').randint(100, 999)}"
    return f"env-{uuid.uuid4().hex[:6]}"


def create_env(name: Optional[str] = None,
               proxy_url: str = "", proxy_enabled: bool = False) -> Tuple[bool, Any]:
    data = ensure_manifest()
    envs = data.setdefault("environments", {})
    if not name:
        name = generate_random_name(envs.keys())
    name = "".join(ch for ch in str(name) if ch.isalnum() or ch in "-_").lower()
    if not name or name in envs:
        return False, f"Среда '{name}' уже существует или некорректное имя"

    mid = uuid.uuid4().hex
    host = f"node-{name}-{uuid.uuid4().hex[:4]}"
    path = env_dir(name)
    home = os.path.join(path, "home")
    workspace = os.path.join(path, "workspace")
    for d in (path, home, workspace):
        os.makedirs(d, exist_ok=True)

    ensure_env_identity_files(name, mid, host)

    cfg_dir = os.path.join(home, ".config", "opencode")
    os.makedirs(cfg_dir, exist_ok=True)
    with open(os.path.join(cfg_dir, "INSTRUCTIONS.md"), "w", encoding="utf-8") as fh:
        fh.write(f"# Среда: {name}\n* Machine ID: {mid}\n* Hostname: {host}\n"
                 f"* Сделано Антоном Ковалкиным, все права защищены.\n")

    link = os.path.join(home, "workspace")
    try:
        if os.path.islink(link) or os.path.exists(link):
            if os.path.isdir(link) and not os.path.islink(link):
                shutil.rmtree(link, ignore_errors=True)
            else:
                os.remove(link)
        os.symlink(workspace, link)
    except Exception:
        pass

    _write_env_bashrc(name, home, workspace)

    readme = os.path.join(workspace, "README.md")
    if not os.path.exists(readme):
        with open(readme, "w", encoding="utf-8") as fh:
            fh.write(f"# Проект среды {name}\n* Папка: `{workspace}`\n"
                     f"* Machine ID: `{mid}`\n* Сделано Антоном Ковалкиным, все права защищены.\n")

    # Mirror folder for Windows Explorer (WSL only, best effort).
    root = export_root()
    if root:
        try:
            os.makedirs(os.path.join(root, name), exist_ok=True)
        except Exception:
            pass

    seed_env_opencode_config(home, workspace, name)

    if proxy_url:
        proxy_url = normalize_proxy(proxy_url)
    write_proxy_config(home, proxy_url, bool(proxy_enabled))

    try:
        if IS_LINUX and os.geteuid() == 0:
            subprocess.run(["chown", "-R", "1000:1000", path], capture_output=True)
    except Exception:
        pass

    envs[name] = {
        "name": name,
        "hostname": host,
        "machine_id": mid,
        "home": home,
        "workspace": workspace,
        "workspace_win": to_display_path(workspace),
        "proxy_url": proxy_url if proxy_enabled else "",
        "proxy_enabled": bool(proxy_enabled),
        "created_at": _now(),
        "description": f"Анонимная изолированная среда {name}",
    }
    data["active"] = name
    save_manifest(data)
    return True, envs[name]


def set_active_env(name: str) -> Tuple[bool, str]:
    data = ensure_manifest()
    if name not in data.get("environments", {}):
        return False, f"Среда '{name}' не существует"
    data["active"] = name
    save_manifest(data)
    info = data["environments"][name]
    ensure_env_identity_files(name, info.get("machine_id"), info.get("hostname"))
    return True, f"Активная среда переключена на '{name}'"


def reset_env(name: str) -> Tuple[bool, Any]:
    data = ensure_manifest()
    envs = data.get("environments", {})
    if name not in envs:
        return False, "Среда не найдена"
    kill_env_processes(name)
    mid, host = uuid.uuid4().hex, f"node-{name}-{uuid.uuid4().hex[:4]}"
    ensure_env_identity_files(name, mid, host)
    home, workspace = env_paths(name)
    for sub in (".cache/opencode", ".local/share/opencode", ".local/state/opencode",
                ".config/opencode"):
        shutil.rmtree(os.path.join(home, sub), ignore_errors=True)
    seed_env_opencode_config(home, workspace, name)
    envs[name]["machine_id"] = mid
    envs[name]["hostname"] = host
    envs[name]["workspace_win"] = to_display_path(workspace)
    save_manifest(data)
    return True, {"message": f"Кэш среды {name} очищен, паспорт обновлен",
                  "name": name, "machine_id": mid, "hostname": host}


def delete_env(name: str, delete_workspace: bool = False) -> Tuple[bool, str]:
    data = ensure_manifest()
    envs = data.get("environments", {})
    if name not in envs:
        return False, "Среда не найдена"
    if name == "default":
        return False, "Среду default удалить нельзя"
    info = envs[name]
    kill_env_processes(name)
    shutil.rmtree(env_dir(name), ignore_errors=True)
    root = export_root()
    if root:
        shutil.rmtree(os.path.join(root, name), ignore_errors=True)
    if delete_workspace:
        shutil.rmtree(info.get("workspace", ""), ignore_errors=True)
    del envs[name]
    if data.get("active") == name:
        data["active"] = "default" if "default" in envs else (next(iter(envs), "default"))
    save_manifest(data)
    return True, f"Среда '{name}' успешно удалена"


def purge_envs(keep_active: bool = True) -> Tuple[bool, str]:
    data = ensure_manifest()
    envs = data.get("environments", {})
    active = data.get("active", "default")
    targets = [n for n in list(envs) if n != "default" and (not keep_active or n != active)]
    for name in targets:
        delete_env(name, delete_workspace=False)
    return True, f"Удалено дополнительных сред: {len(targets)}"


# ---------------------------------------------------------------------------
# Provider config
# ---------------------------------------------------------------------------

DEFAULT_PROVIDER_CONFIG = {"provider": "opencode", "model": "", "apiKey": "", "updated_at": ""}


def load_provider_config() -> Dict[str, Any]:
    cfg = read_json(PROVIDER_CONFIG_FILE, None)
    if isinstance(cfg, dict):
        out = dict(DEFAULT_PROVIDER_CONFIG)
        out.update(cfg)
        return out
    return dict(DEFAULT_PROVIDER_CONFIG)


def save_provider_config(cfg: Dict[str, Any]) -> None:
    write_json(PROVIDER_CONFIG_FILE, cfg)


def generate_opencode_json(provider_cfg: Dict[str, Any]) -> Dict[str, Any]:
    provider = (provider_cfg.get("provider") or "opencode").strip()
    model = (provider_cfg.get("model") or "").strip()
    api_key = (provider_cfg.get("apiKey") or "").strip()
    cfg: Dict[str, Any] = {"$schema": "https://opencode.ai/config.json"}
    if model:
        cfg["model"] = model
    if provider in ("google", "groq", "openrouter", "deepseek") and api_key:
        cfg["providers"] = {provider: {"settings": {"apiKey": api_key}}}
    return cfg


def apply_provider_to_env(env_name: str, info: Dict[str, Any],
                          provider_cfg: Dict[str, Any]) -> None:
    home = info.get("home") or env_paths(env_name)[0]
    workspace = info.get("workspace") or env_paths(env_name)[1]
    cfg = generate_opencode_json(provider_cfg)
    cfg_dir = os.path.join(home, ".config", "opencode")
    os.makedirs(cfg_dir, exist_ok=True)
    write_json(os.path.join(cfg_dir, "opencode.json"), cfg)

    if workspace and os.path.isdir(workspace):
        ws_cfg = os.path.join(workspace, ".opencode")
        if "providers" in cfg or "model" in cfg:
            os.makedirs(ws_cfg, exist_ok=True)
            write_json(os.path.join(ws_cfg, "opencode.json"), cfg)
        else:
            try:
                os.remove(os.path.join(ws_cfg, "opencode.json"))
            except Exception:
                pass

    state_dir = os.path.join(home, ".local", "state", "opencode")
    os.makedirs(state_dir, exist_ok=True)
    model_id = (provider_cfg.get("model") or "").strip()
    provider_id = provider_cfg.get("provider", "opencode")
    clean_model = model_id.split("/")[-1] if model_id else ""
    model_json = os.path.join(state_dir, "model.json")
    if clean_model:
        write_json(model_json, {
            "recent": [{"providerID": provider_id, "modelID": clean_model}],
            "favorite": [{"providerID": provider_id, "modelID": clean_model}],
            "variant": {},
        })
    else:
        try:
            os.remove(model_json)
        except Exception:
            pass

    tui_dir = os.path.join(state_dir, "latest", "tui")
    os.makedirs(tui_dir, exist_ok=True)
    write_json(os.path.join(tui_dir, "go-upsell.json"),
               {"lastSeenAt": 9999999999999, "dontShow": True})

    for p in (os.path.join(state_dir, "service.json"),
              os.path.join(cfg_dir, "service.json")):
        try:
            os.remove(p)
        except Exception:
            pass

    bashrc = os.path.join(home, ".bashrc")
    if os.path.exists(bashrc):
        try:
            with open(bashrc, "r", encoding="utf-8") as fh:
                lines = [ln for ln in fh if not any(k in ln for k in ("_API_KEY", "OPENCODE_MODEL"))]
            key = (provider_cfg.get("apiKey") or "").strip()
            if key:
                env_name_key = {"google": "GEMINI_API_KEY", "groq": "GROQ_API_KEY",
                                "openrouter": "OPENROUTER_API_KEY",
                                "deepseek": "DEEPSEEK_API_KEY"}.get(provider_id)
                if env_name_key:
                    lines.append(f'export {env_name_key}={shlex.quote(key)}\n')
                    if provider_id == "google":
                        lines.append(f'export GOOGLE_API_KEY={shlex.quote(key)}\n')
            with open(bashrc, "w", encoding="utf-8") as fh:
                fh.writelines(lines)
        except Exception:
            pass


def seed_env_opencode_config(home: str, workspace: Optional[str] = None,
                             env_name: Optional[str] = None) -> None:
    info = {"home": home, "workspace": workspace or ""}
    apply_provider_to_env(env_name or "default", info, load_provider_config())


# ---------------------------------------------------------------------------
# Proxy helpers
# ---------------------------------------------------------------------------

def normalize_proxy(url: str) -> str:
    url = (url or "").strip()
    if url and "://" not in url:
        url = "http://" + url
    return url


def is_socks(url: str) -> bool:
    return any((url or "").lower().startswith(s) for s in
               ("socks5://", "socks5h://", "socks4://", "socks4a://", "socks://"))


def get_env_bridge_port(env_name: str) -> int:
    return 10801 + (zlib.crc32((env_name or "default").encode("utf-8")) % 9000)


def read_proxy_config(home: str, allow_global: bool = True) -> Tuple[bool, str, bool]:
    """Return (enabled, url, is_global).  An explicit local file wins."""
    cfg_path = os.path.join(home, ".proxy_config")
    if os.path.exists(cfg_path):
        enabled, url = False, ""
        for line in _read_text(cfg_path).splitlines():
            if line.startswith("PROXY_ENABLED="):
                enabled = "yes" in line.lower()
            elif line.startswith("PROXY_URL="):
                url = line.split("=", 1)[1].strip().strip('"\'')
        return enabled, normalize_proxy(url), False
    if allow_global:
        gp = get_global_proxy()
        if gp.get("enabled") and gp.get("url"):
            return True, normalize_proxy(gp["url"]), True
    return False, "", False


def write_proxy_config(home: str, url: str, enabled: bool) -> bool:
    url = normalize_proxy(url)
    try:
        os.makedirs(home, exist_ok=True)
        with open(os.path.join(home, ".proxy_config"), "w", encoding="utf-8") as fh:
            fh.write(f'PROXY_ENABLED="{"yes" if enabled else "no"}"\nPROXY_URL="{url}"\n')
        curlrc = os.path.join(home, ".curlrc")
        if enabled and url:
            with open(curlrc, "w", encoding="utf-8") as fh:
                fh.write(f'proxy = "{url}"\n')
        elif os.path.exists(curlrc):
            os.remove(curlrc)
        return True
    except Exception:
        return False


def get_global_proxy() -> Dict[str, Any]:
    cfg = read_json(GLOBAL_PROXY_FILE, None)
    if isinstance(cfg, dict):
        return {"enabled": bool(cfg.get("enabled")), "url": cfg.get("url", "")}
    data = ensure_manifest()
    gp = data.get("global_proxy") or {}
    return {"enabled": bool(gp.get("enabled")), "url": gp.get("url", "")}


def set_global_proxy(url: str, enabled: bool = True,
                     apply_to_all_envs: bool = False) -> Dict[str, Any]:
    url = normalize_proxy(url)
    cfg = {"enabled": bool(enabled), "url": url}
    write_json(GLOBAL_PROXY_FILE, cfg)
    data = ensure_manifest()
    data["global_proxy"] = cfg
    if apply_to_all_envs:
        for name, info in data.get("environments", {}).items():
            info["proxy_url"] = url
            info["proxy_enabled"] = bool(enabled)
            write_proxy_config(info.get("home", ""), url, bool(enabled))
            stop_bridge(name)
    save_manifest(data)
    return cfg


def _curl(args: List[str], timeout: float = 12.0) -> Tuple[int, str, str]:
    try:
        proc = subprocess.run(["curl", "-sS"] + args, capture_output=True,
                              text=True, timeout=timeout)
        return proc.returncode, proc.stdout, proc.stderr
    except FileNotFoundError:
        return 127, "", "curl not found"
    except subprocess.TimeoutExpired:
        return 124, "", "timeout"
    except Exception as exc:
        return 1, "", str(exc)


def proxy_tls_check(proxy_url: str, timeout: int = 10) -> Dict[str, Any]:
    """Verify that HTTPS through the proxy has a trusted certificate chain.

    This is the check that prevents OpenCode's
    ``SELF_SIGNED_CERT_IN_CHAIN`` / ``certificate subject name`` failures.
    Cheap ``https://api.ipify.org`` checks are not enough: many free proxies
    MITM only selected hosts such as opencode.ai.
    """
    proxy_url = normalize_proxy(proxy_url)
    if not proxy_url:
        return {"ok": True, "tls_ok": True, "error": "", "checks": []}

    targets = [
        ("models", "https://models.opencode.ai/experimental/v2.0/api.json?type=chat,decision,image"),
        ("opencode", "https://opencode.ai/"),
    ]
    result: Dict[str, Any] = {"ok": False, "tls_ok": False, "error": "",
                              "checks": [], "models_ok": False,
                              "tls_error": False, "network_error": False,
                              "reachable": False}
    for key, url in targets:
        rc, out, err = _curl([
            "--connect-timeout", "4", "--max-time", str(timeout), "-x", proxy_url,
            "-r", "0-65535",
            "-o", os.devnull, "-w", "%{http_code}", "-H", "User-Agent: opencode/2.2.1",
            url,
        ], timeout + 3)
        code = out.strip()
        item = {"name": key, "rc": rc, "http": code, "error": err.strip()[:180]}
        result["checks"].append(item)
        if rc == 0 and code.isdigit() and 100 <= int(code) < 600:
            result["reachable"] = True
            if key == "models":
                result["models_ok"] = True
            continue

        low = err.lower()
        is_tls = (rc == 60 or "certificate" in low or "self signed" in low or
                  "unable to get local issuer" in low or "unknown ca" in low or
                  "certificate verify" in low)
        if is_tls:
            result["error"] = f"TLS/SSL: {err.strip()[:140]}"
            result["tls_error"] = True
            return result
        # Timeouts / refused connections are not MITM.  They mean the proxy is
        # slow or unreachable; never report them as a certificate problem.
        result["network_error"] = True
        result.setdefault("warnings", []).append(
            f"{key}: {err.strip()[:100] or code or 'timeout'}")
        continue

    result["ok"] = True
    result["tls_ok"] = True
    return result


def proxy_preflight_ex(proxy_url: str) -> Dict[str, Any]:
    """Preflight result with a clear fatal/non-fatal distinction.

    Fatal (TLS interception) must drop the proxy: otherwise OpenCode aborts
    with SELF_SIGNED_CERT_IN_CHAIN.  Timeouts are only warnings: dropping the
    proxy there would silently send an "anonymous" environment through the
    real IP.
    """
    res = proxy_tls_check(proxy_url, timeout=8)
    fatal = bool(res.get("tls_error"))
    warnings = list(res.get("warnings", []))
    if res.get("network_error") and res.get("error"):
        warnings.append(res["error"])
    return {"ok": not fatal, "fatal": fatal,
            "error": res.get("error", ""), "warnings": warnings,
            "checks": res.get("checks", [])}


def proxy_preflight(proxy_url: str) -> Tuple[bool, str]:
    res = proxy_preflight_ex(proxy_url)
    return bool(res.get("ok")), res.get("error", "")



def test_proxy_connectivity(proxy_url: str, timeout: float = 6.0) -> Dict[str, Any]:
    """Check a proxy for real OpenCode use.

    Slow free proxies often time out on the ip-api geo request while still
    being able to serve HTTPS/inference.  A geo timeout alone is therefore
    not a failure: fall back to ipify and, if even that is slow, keep the
    proxy when its TLS handshake to opencode.ai is clean.
    """
    proxy_url = normalize_proxy(proxy_url)
    if not proxy_url:
        return {"success": False, "url": "", "error": "URL не указан"}
    start = time.time()
    geo: Dict[str, Any] = {}
    geo_error = ""
    rc, out, err = _curl([
        "--connect-timeout", "4", "--max-time", str(int(timeout)), "-x", proxy_url,
        "http://ip-api.com/json/?fields=status,country,countryCode,city,query,org",
    ], timeout + 2)
    latency = int((time.time() - start) * 1000)
    if rc == 0 and out:
        try:
            candidate = json.loads(out.strip())
            if candidate.get("status") == "success":
                geo = candidate
            else:
                geo_error = candidate.get("message", "IP API status fail")
        except Exception:
            geo_error = "Некорректный ответ IP API"
    else:
        geo_error = err.strip()[:140] or "Таймаут / нет ответа"

    if not geo:
        rc2, out2, _err2 = _curl([
            "--connect-timeout", "4", "--max-time", str(int(timeout)), "-x", proxy_url,
            "https://api.ipify.org?format=json",
        ], timeout + 2)
        ip = ""
        if rc2 == 0 and out2:
            try:
                ip = json.loads(out2.strip()).get("ip", "")
            except Exception:
                ip = ""
        if ip:
            geo = {"query": ip, "country": "Неизвестно", "countryCode": "UN",
                   "city": "", "org": ""}
            # Resolve geo directly (not through the slow proxy).
            rc3, out3, _err3 = _curl([
                "--connect-timeout", "4", "--max-time", "8",
                f"http://ip-api.com/json/{ip}?fields=status,country,countryCode,city,query,org",
            ], 12)
            if rc3 == 0 and out3:
                try:
                    direct = json.loads(out3.strip())
                    if direct.get("status") == "success":
                        geo.update({k: direct.get(k, geo.get(k))
                                    for k in ("country", "countryCode", "city", "org")})
                except Exception:
                    pass

    tls = proxy_tls_check(proxy_url, timeout=max(8, int(timeout)))
    base = {
        "url": proxy_url,
        "ip": geo.get("query", proxy_url.split("://")[-1].split(":")[0]),
        "country": geo.get("country") or "Неизвестно",
        "country_code": geo.get("countryCode") or "UN",
        "city": geo.get("city", ""),
        "org": geo.get("org", ""),
        "latency": latency,
        "type": "SOCKS" if is_socks(proxy_url) else "HTTP",
        "tls_ok": bool(tls.get("tls_ok")),
        "tls_error": tls.get("error", ""),
        "checks": tls.get("checks", []),
    }
    if not tls.get("ok"):
        base["success"] = False
        base["error"] = "Прокси перехватывает TLS: " + (tls.get("error") or "сертификат не доверен")
        return base
    if not tls.get("reachable"):
        base["success"] = False
        base["error"] = "opencode.ai недоступен через прокси: " + (
            tls.get("error") or "; ".join(w for w in tls.get("warnings", [])) or "таймаут")
        return base
    base["success"] = True
    base["error"] = ""
    base["warning"] = "" if geo else f"геолокация не определена: {geo_error}"
    return base


def get_proxies_catalog() -> List[Dict[str, Any]]:
    for path in (CATALOG_FILE, PACKAGE_CATALOG_FILE):
        data = read_json(path, None)
        if isinstance(data, list):
            return data
    return []


def save_proxies_catalog(entries: List[Dict[str, Any]]) -> None:
    write_json(CATALOG_FILE, entries)
    if _writable_dir(os.path.dirname(PACKAGE_CATALOG_FILE)):
        write_json(PACKAGE_CATALOG_FILE, entries)


def check_env_ip(env_name: Optional[str] = None) -> Dict[str, Any]:
    target = env_name or get_active_env_name()
    home, _ = env_paths(target)
    enabled, url, is_global = read_proxy_config(home)
    cmd = ["-s", "--connect-timeout", "4", "--max-time", "7",
           "http://ip-api.com/json/?fields=status,message,country,countryCode,city,query,org"]
    if enabled and url:
        cmd = ["-x", url] + cmd
    try:
        proc = subprocess.run(["curl"] + cmd, capture_output=True, text=True, timeout=9)
        if proc.returncode == 0 and proc.stdout:
            data = json.loads(proc.stdout.strip())
            if data.get("status") == "success":
                data.update(proxy_active=enabled and bool(url), proxy_url=url,
                            is_global=is_global, env=target)
                if enabled and url:
                    tls = proxy_tls_check(url, timeout=8)
                    data["tls_ok"] = bool(tls.get("tls_ok"))
                    data["tls_error"] = tls.get("error", "")
                return data
    except Exception:
        pass
    return {"status": "fail", "query": "Не удалось определить",
            "country": "Офлайн или ошибка сети", "city": "", "org": "",
            "proxy_active": enabled and bool(url), "proxy_url": url,
            "is_global": is_global, "env": target}


# ---------------------------------------------------------------------------
# Provider connectivity test
# ---------------------------------------------------------------------------

def test_provider_api(provider: str, api_key: str, model: str,
                      env_name: Optional[str] = None) -> Tuple[bool, str]:
    start = time.time()
    home, _ = env_paths(env_name)
    enabled, proxy_url, _ = read_proxy_config(home)
    if not enabled:
        proxy_url = ""
    proxy_url = normalize_proxy(proxy_url)
    headers = {"Content-Type": "application/json", "User-Agent": f"opencode/{APP_VERSION}"}
    try:
        if provider == "opencode":
            clean = (model or "big-pickle").replace("opencode/", "")
            url = "https://opencode.ai/inference/openai/v1/chat/completions"
            payload = json.dumps({"model": clean,
                                  "messages": [{"role": "user", "content": "hi"}],
                                  "stream": False})
            cmd = ["-sS", "-w", "\n%{http_code}", "--connect-timeout", "5",
                   "--max-time", "20", "-X", "POST", url,
                   "-H", "Content-Type: application/json",
                   "-H", f"Authorization: Bearer {api_key or 'public'}",
                   "-H", f"User-Agent: opencode/{APP_VERSION}", "-d", payload]
            if proxy_url:
                cmd += ["-x", proxy_url]
            rc, out, err = _curl(cmd, 25)
            if rc != 0:
                if "certificate" in err.lower() or "SSL" in err:
                    return False, ("Прокси перехватывает TLS (self-signed certificate). "
                                   "OpenCode не сможет работать через него. Выберите прокси "
                                   "с чистым HTTPS или отключите прокси.")
                return False, f"Ошибка подключения через {proxy_url or 'Direct'}: {err.strip()[:140]}"
            parts = out.rsplit("\n", 1)
            body = parts[0] if len(parts) == 2 else out
            code = int(parts[1]) if len(parts) == 2 and parts[1].strip().isdigit() else 0
            latency = int((time.time() - start) * 1000)
            if 200 <= code < 300:
                return True, f"Успешно подключено ({clean})! Задержка: {latency} мс"
            if "FreeUsageLimitError" in body:
                return False, (f"429 (IP: {proxy_url or 'прямой IP'}): лимит бесплатных "
                               f"запросов OpenCode исчерпан до 03:00 МСК. Задайте чистый "
                               f"индивидуальный прокси или свой API-ключ.")
            return False, f"Ошибка {code}: {body[:160]}"

        if provider == "google":
            clean = (model or "gemini-2.5-flash").replace("google/", "")
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{clean}:generateContent?key={api_key}"
            body = json.dumps({"contents": [{"parts": [{"text": "hi"}]}]}).encode()
        elif provider == "groq":
            clean = (model or "llama-3.3-70b-versatile").replace("groq/", "")
            url = "https://api.groq.com/openai/v1/chat/completions"
            headers["Authorization"] = f"Bearer {api_key}"
            body = json.dumps({"model": clean, "messages": [{"role": "user", "content": "hi"}]}).encode()
        elif provider == "openrouter":
            clean = (model or "meta-llama/llama-3.3-70b-instruct:free").replace("openrouter/", "")
            url = "https://openrouter.ai/api/v1/chat/completions"
            headers["Authorization"] = f"Bearer {api_key}"
            body = json.dumps({"model": clean, "messages": [{"role": "user", "content": "hi"}]}).encode()
        elif provider == "deepseek":
            clean = (model or "deepseek-chat").replace("deepseek/", "")
            url = "https://api.deepseek.com/chat/completions"
            headers["Authorization"] = f"Bearer {api_key}"
            body = json.dumps({"model": clean, "messages": [{"role": "user", "content": "hi"}]}).encode()
        else:
            return False, "Неизвестный провайдер"

        import urllib.error
        import urllib.request
        req = urllib.request.Request(url, data=body, headers=headers)
        if proxy_url:
            opener = urllib.request.build_opener(
                urllib.request.ProxyHandler({"http": proxy_url, "https": proxy_url}))
            ctx = opener.open(req, timeout=20)
        else:
            ctx = urllib.request.urlopen(req, timeout=20)
        with ctx as resp:
            resp.read(1024)
        latency = int((time.time() - start) * 1000)
        return True, f"Успешно подключено! Задержка: {latency} мс"
    except Exception as exc:
        text = str(exc)
        if "certificate" in text.lower() or "SSL" in text:
            return False, ("Прокси перехватывает TLS (self-signed certificate). "
                           "Выберите прокси с чистым HTTPS или отключите прокси.")
        return False, f"Ошибка подключения: {text[:180]}"


# ---------------------------------------------------------------------------
# Sessions
# ---------------------------------------------------------------------------

def get_env_sessions(home_dir: str) -> List[Dict[str, Any]]:
    db_path = os.path.join(home_dir, ".local", "share", "opencode", "opencode.db")
    if not os.path.exists(db_path):
        return []
    tmp_path = ""
    try:
        fd, tmp_path = tempfile.mkstemp(suffix=".db")
        os.close(fd)
        shutil.copy2(db_path, tmp_path)
        con = sqlite3.connect(tmp_path)
        cur = con.cursor()
        tables = {row[0] for row in cur.execute(
            "SELECT name FROM sqlite_master WHERE type='table'").fetchall()}
        table = "session_v2" if "session_v2" in tables else ("session" if "session" in tables else "")
        if not table:
            con.close()
            return []
        cols = {row[1] for row in cur.execute(f"PRAGMA table_info({table})").fetchall()}
        title_col = "title" if "title" in cols else "''"
        dir_col = "directory" if "directory" in cols else "''"
        upd_col = "time_updated" if "time_updated" in cols else ("time_created" if "time_created" in cols else "0")
        archived = f"WHERE time_archived IS NULL" if "time_archived" in cols else ""
        rows = cur.execute(
            f"SELECT id, {title_col}, {dir_col}, {upd_col} FROM {table} {archived} "
            f"ORDER BY {upd_col} DESC LIMIT 20").fetchall()
        con.close()
        return [{"id": r[0], "title": r[1] or "Сессия OpenCode",
                 "directory": r[2] or "", "time_updated": r[3]} for r in rows]
    except Exception:
        return []
    finally:
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.remove(tmp_path)
            except Exception:
                pass


# ---------------------------------------------------------------------------
# Path conversion / display
# ---------------------------------------------------------------------------

def _wsl_distro() -> str:
    return os.environ.get("WSL_DISTRO_NAME") or "Ubuntu"


def to_display_path(path: str) -> str:
    if not path:
        return ""
    if IS_WINDOWS:
        return os.path.abspath(path).replace("/", "\\")
    p = os.path.abspath(path)
    if IS_WSL:
        m = re.match(r"^/mnt/([a-zA-Z])(/.*)?$", p)
        if m:
            rest = (m.group(2) or "").replace("/", "\\")
            return f"{m.group(1).upper()}:{rest or chr(92)}"
        # Env workspaces get a stable Windows mirror path.
        for base in ("/var/envs", os.path.join(ENVS_DIR, "")):
            base = base.rstrip("/")
            m = re.match(rf"^{re.escape(base)}/([^/]+)(?:/workspace)?(?:/(.*))?$", p)
            if m:
                name, rest = m.group(1), (m.group(2) or "").replace("/", "\\")
                root = os.path.join(WINDOWS_WORKSPACE_ROOT, name)
                return root.replace("/", "\\") + (("\\" + rest) if rest else "")
        return "\\\\wsl.localhost\\" + _wsl_distro() + p.replace("/", "\\")
    return p


def to_native_path(path: str) -> str:
    path = (path or "").strip().strip("'\"")
    if not path:
        return path
    if IS_WSL and re.match(r"^[A-Za-z]:[\\/]", path):
        drive = path[0].lower()
        rest = path[2:].replace("\\", "/").lstrip("/")
        return f"/mnt/{drive}/{rest}"
    if IS_WINDOWS and path.startswith("/"):
        # Best effort for paths coming from a WSL instance.
        return path.replace("/", "\\")
    return os.path.abspath(os.path.expanduser(path))


def get_dir_contents(path: str) -> List[Dict[str, Any]]:
    path = os.path.abspath(os.path.expanduser(path))
    if not os.path.exists(path):
        return []
    items = []
    try:
        for entry in os.scandir(path):
            try:
                st = entry.stat(follow_symlinks=False)
                is_dir = entry.is_dir(follow_symlinks=False)
                items.append({
                    "name": entry.name,
                    "path": entry.path,
                    "win_path": to_display_path(entry.path),
                    "is_dir": is_dir,
                    "is_link": entry.is_symlink(),
                    "size": 0 if is_dir else st.st_size,
                    "mtime": datetime.datetime.fromtimestamp(st.st_mtime).strftime("%d.%m.%Y %H:%M"),
                    "ext": "" if is_dir else os.path.splitext(entry.name)[1].lower(),
                })
            except Exception:
                pass
    except Exception:
        pass
    items.sort(key=lambda x: (not x["is_dir"], x["name"].lower()))
    return items


# ---------------------------------------------------------------------------
# Process management
# ---------------------------------------------------------------------------

def _pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def _linux_process_snapshot() -> List[Tuple[int, str, Dict[str, str]]]:
    out = []
    try:
        for pid_str in os.listdir("/proc"):
            if not pid_str.isdigit():
                continue
            pid = int(pid_str)
            try:
                with open(f"/proc/{pid}/cmdline", "rb") as fh:
                    raw = fh.read()
                cmd = raw.decode("utf-8", "ignore").replace("\x00", " ").strip()
                env = {}
                with open(f"/proc/{pid}/environ", "rb") as fh:
                    for item in fh.read().decode("utf-8", "ignore").split("\x00"):
                        if "=" in item:
                            k, v = item.split("=", 1)
                            env[k] = v
                out.append((pid, cmd, env))
            except Exception:
                pass
    except Exception:
        pass
    return out


def find_env_pids(env_name: str) -> List[int]:
    home, _ = env_paths(env_name)
    pids: List[int] = []
    if IS_LINUX:
        for pid, cmd, env in _linux_process_snapshot():
            if pid in (os.getpid(), os.getppid()):
                continue
            if "opencode-bin" not in cmd and "/opencode " not in cmd and not cmd.rstrip().endswith("/opencode"):
                continue
            if env.get("OPENCODE_ENV") == env_name or env.get("HOME") == home:
                pids.append(pid)
    elif IS_MACOS:
        try:
            proc = subprocess.run(["ps", "-axo", "pid=,command="], capture_output=True,
                                  text=True, timeout=5)
            for line in proc.stdout.splitlines():
                line = line.strip()
                if not line:
                    continue
                pid_s, _, cmd = line.partition(" ")
                if not pid_s.isdigit():
                    continue
                pid = int(pid_s)
                if pid in (os.getpid(), os.getppid()):
                    continue
                if "opencode" not in cmd:
                    continue
                try:
                    envp = subprocess.run(["ps", "eww", "-p", str(pid)], capture_output=True,
                                          text=True, timeout=3).stdout
                except Exception:
                    envp = ""
                if f"OPENCODE_ENV={env_name}" in envp or f"HOME={home}" in envp:
                    pids.append(pid)
        except Exception:
            pass
    if not pids:
        # PIDs recorded by the launcher (works everywhere).
        record = read_json(os.path.join(RUN_DIR, f"env-{env_name}.json"), {}) or {}
        if isinstance(record, dict):
            for pid in record.get("pids", []):
                if isinstance(pid, int) and _pid_alive(pid):
                    pids.append(pid)
    return sorted(set(pids))


def kill_pids(pids: Iterable[int], timeout: float = 3.0) -> int:
    pids = [p for p in set(pids) if p and p not in (os.getpid(), os.getppid())]
    killed = 0
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGKILL):
        alive = []
        for pid in pids:
            if not _pid_alive(pid):
                continue
            try:
                os.kill(pid, sig)
                alive.append(pid)
            except Exception:
                pass
        killed += len(pids) - len(alive) if sig == signal.SIGINT else 0
        if not alive:
            break
        time.sleep(min(timeout / 3, 0.4))
    return len(pids)


def kill_env_processes(env_name: str) -> int:
    pids = find_env_pids(env_name)
    kill_pids(pids)
    stop_bridge(env_name)
    try:
        os.remove(os.path.join(RUN_DIR, f"env-{env_name}.json"))
    except Exception:
        pass
    return len(pids)


def find_processes(names: Iterable[str], exclude_self: bool = True) -> List[int]:
    wanted = {n.lower() for n in names}
    exclude = {os.getpid(), os.getppid()} if exclude_self else set()
    result: List[int] = []
    if IS_LINUX:
        for pid, cmd, _env in _linux_process_snapshot():
            if pid in exclude:
                continue
            if any(name in cmd.lower() for name in wanted):
                result.append(pid)
    elif IS_MACOS:
        try:
            proc = subprocess.run(["ps", "-axo", "pid=,command="], capture_output=True,
                                  text=True, timeout=5)
            for line in proc.stdout.splitlines():
                line = line.strip()
                pid_s, _, cmd = line.partition(" ")
                if pid_s.isdigit() and int(pid_s) not in exclude:
                    if any(name in cmd.lower() for name in wanted):
                        result.append(int(pid_s))
        except Exception:
            pass
    return sorted(set(result))


def _port_open(port: int, host: str = "127.0.0.1", timeout: float = 0.35) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except Exception:
        return False


def kill_port_processes(port: int, names: Iterable[str] = ("ttyd",)) -> None:
    wanted = {n.lower() for n in names}
    if IS_LINUX:
        for pid, cmd, _env in _linux_process_snapshot():
            if pid in (os.getpid(), os.getppid()):
                continue
            if not any(w in cmd.lower() for w in wanted):
                continue
            if re.search(rf"(?:^|\s)-p\s*{port}(?:\s|$)", cmd):
                kill_pids([pid])
    elif IS_MACOS:
        for pid in find_processes(wanted):
            try:
                cmd = subprocess.run(["ps", "-p", str(pid), "-o", "command="],
                                     capture_output=True, text=True, timeout=3).stdout
                if re.search(rf"(?:^|\s)-p\s*{port}(?:\s|$)", cmd):
                    kill_pids([pid])
            except Exception:
                pass


# ---------------------------------------------------------------------------
# ttyd helpers
# ---------------------------------------------------------------------------

def _binary_matches_platform(path: str) -> bool:
    try:
        with open(path, "rb") as fh:
            magic = fh.read(4)
    except Exception:
        return False
    if IS_MACOS:
        return magic in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe",
                         b"\xca\xfe\xba\xbe", b"\xfe\xed\xfa\xcf",
                         b"\xfe\xed\xfa\xce", b"\xbe\xba\xfe\xca")
    if IS_LINUX:
        return magic == b"\x7fELF"
    if IS_WINDOWS:
        return magic[:2] == b"MZ"
    return False


def find_ttyd() -> str:
    local = os.path.join(BIN_DIR, "ttyd")
    if os.path.isfile(local) and os.access(local, os.X_OK) and _binary_matches_platform(local):
        return local
    found = shutil.which("ttyd")
    if found:
        return found
    # Homebrew on Apple Silicon / Intel
    for cand in ("/opt/homebrew/bin/ttyd", "/usr/local/bin/ttyd"):
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return ""


def find_opencode_bin() -> str:
    explicit = (os.environ.get("OPENCODE_BIN") or "").strip()
    if explicit and os.path.exists(explicit):
        return explicit
    local = os.path.join(BIN_DIR, "opencode-bin")
    if os.path.isfile(local) and _binary_matches_platform(local):
        return local
    found = shutil.which("opencode")
    if found:
        return found
    return local


def ttyd_status() -> Dict[str, Any]:
    path = os.path.join(RUN_DIR, "ttyd.json")
    st = read_json(path, {}) or {}
    pid = st.get("pid")
    ok = bool(pid and _pid_alive(int(pid)) and _port_open(int(st.get("port", 7681))))
    return {"running": ok, **st} if isinstance(st, dict) else {"running": False}


def stop_terminal() -> None:
    st = read_json(os.path.join(RUN_DIR, "ttyd.json"), {}) or {}
    pid = st.get("pid") if isinstance(st, dict) else None
    port = int(st.get("port", 7681)) if isinstance(st, dict) else 7681
    if pid:
        kill_pids([int(pid)], timeout=2)
    kill_port_processes(port)
    try:
        os.remove(os.path.join(RUN_DIR, "ttyd.json"))
    except Exception:
        pass


def start_terminal(env_name: Optional[str] = None, session: Optional[str] = None,
                   port: int = 7681, run_opencode: bool = True) -> Tuple[bool, Any]:
    if IS_WINDOWS:
        return False, "Веб-терминал требует WSL/Linux/macOS (ttyd не поддерживает Windows напрямую)"
    ttyd = find_ttyd()
    if not ttyd:
        return False, ("ttyd не найден. Установите его: Linux — пакет ttyd, "
                       "macOS — brew install ttyd, WSL — sudo apt install ttyd.")
    env_name = env_name or get_active_env_name()
    home, workspace = env_paths(env_name)
    if env_name not in ensure_manifest().get("environments", {}):
        return False, f"Среда '{env_name}' не найдена"

    if session and not re.fullmatch(r"[A-Za-z0-9_.:-]+", session):
        return False, "Некорректный ID сессии"

    stop_terminal()
    kill_env_processes(env_name)
    time.sleep(0.2)
    if _port_open(port):
        return False, f"Порт {port} занят другим процессом"

    index = os.path.join(SHARE_DIR, "ttyd", "index.html")
    if not os.path.exists(index):
        index = os.path.join(CONFIG_DIR, "ttyd_index.html")
    env_mgr = os.path.join(BIN_DIR, "env-mgr")
    run_cmd = "opencode" + (f" -s {session}" if session else "")
    cmd = [ttyd, "-p", str(port), "-W", "-I", index, "-w", workspace,
           "-t", "fontSize=14", sys.executable, env_mgr, "switch", env_name]
    if run_opencode:
        cmd += ["--run", run_cmd]
    log_path = os.path.join(RUN_DIR, "ttyd.log")
    try:
        with open(log_path, "ab") as log:
            proc = subprocess.Popen(cmd, stdout=log, stderr=log, stdin=subprocess.DEVNULL,
                                    cwd=workspace, start_new_session=True,
                                    env={**os.environ, "OPENCODE_ENV": env_name,
                                         "HOME": home, "TERM": "xterm-256color"})
    except Exception as exc:
        return False, f"Не удалось запустить ttyd: {exc}"

    write_json(os.path.join(RUN_DIR, "ttyd.json"),
               {"pid": proc.pid, "port": port, "env": env_name,
                "session": session or "", "started": _now()})
    for _ in range(50):
        if _port_open(port):
            return True, {"url": f"http://localhost:{port}/?t={int(time.time())}",
                          "port": port, "pid": proc.pid, "env": env_name}
        if proc.poll() is not None:
            break
        time.sleep(0.1)
    tail = ""
    try:
        with open(log_path, "r", encoding="utf-8", errors="replace") as fh:
            tail = fh.read()[-600:]
    except Exception:
        pass
    stop_terminal()
    return False, f"ttyd не открыл порт {port}. {tail}".strip()


# ---------------------------------------------------------------------------
# Proxy bridge control
# ---------------------------------------------------------------------------

def stop_bridge(env_name: str) -> None:
    try:
        bridge = os.path.join(BIN_DIR, "opencode-proxy-bridge")
        subprocess.run([sys.executable, bridge, "stop", str(get_env_bridge_port(env_name))],
                       capture_output=True, timeout=5)
    except Exception:
        pass


def start_bridge(env_name: str, socks_url: str) -> str:
    port = get_env_bridge_port(env_name)
    try:
        bridge = os.path.join(BIN_DIR, "opencode-proxy-bridge")
        subprocess.run([sys.executable, bridge, "start", socks_url, str(port)],
                       capture_output=True, timeout=8)
    except Exception:
        pass
    return f"http://127.0.0.1:{port}"


# ---------------------------------------------------------------------------
# CLI helpers used by the bash wrapper and installers
# ---------------------------------------------------------------------------

def shell_exports(env_name: str) -> str:
    data = ensure_manifest()
    info = data.get("environments", {}).get(env_name)
    if not info:
        env_name, info = "default", data["environments"]["default"]
    home = info.get("home") or default_env_home()
    workspace = info.get("workspace") or default_env_workspace()
    enabled, url, is_global = read_proxy_config(home)
    bin_path = find_opencode_bin()
    values = {
        "ENV_PLATFORM": PLATFORM,
        "ENV_NAME": env_name,
        "ENV_HOME": home,
        "ENV_WS": workspace,
        "ENV_META": env_dir(env_name),
        "ENV_DATA": STATE_DIR,
        "ENV_MACHINE_ID": info.get("machine_id", ""),
        "ENV_HOSTNAME": info.get("hostname", ""),
        "ENV_PROXY_ENABLED": "yes" if enabled else "no",
        "ENV_PROXY_URL": url,
        "ENV_PROXY_GLOBAL": "yes" if is_global else "no",
        "ENV_OPENCODE_BIN": bin_path,
        "ENV_TTYD": find_ttyd(),
        "ENV_ISOLATION": "unshare" if (IS_LINUX and not is_wsl1()
                                        and shutil.which("unshare")
                                        and shutil.which("setpriv")) else "user",
    }
    lines = [f"export {k}={shlex.quote(str(v))}" for k, v in values.items()]
    return "\n".join(lines)


def main(argv: List[str]) -> int:
    if not argv or argv[0] in ("help", "--help", "-h"):
        print("station_core.py: shell-exports <env> | proxy-preflight <url> | platform | status")
        return 0
    cmd = argv[0]
    if cmd == "shell-exports":
        print(shell_exports(argv[1] if len(argv) > 1 else ""))
        return 0
    if cmd == "proxy-preflight":
        res = proxy_preflight_ex(argv[1] if len(argv) > 1 else "")
        for warning in res.get("warnings", []):
            print(f"warning: {warning}", file=sys.stderr)
        if res.get("fatal"):
            print(res.get("error", ""))
            return 3
        return 0
    if cmd == "platform":
        print(json.dumps({
            "platform": PLATFORM, "station_root": STATION_ROOT,
            "state_dir": STATE_DIR, "envs_dir": ENVS_DIR,
            "legacy_layout": LEGACY_LAYOUT, "data_writable": _writable_dir(STATE_DIR),
            "ttyd": find_ttyd(), "opencode_bin": find_opencode_bin(),
        }, ensure_ascii=False, indent=2))
        return 0
    if cmd == "status":
        data = ensure_manifest()
        print(json.dumps({"active": data.get("active"), "environments": list(data.get("environments", {})),
                          "state_dir": STATE_DIR, "platform": PLATFORM}, ensure_ascii=False, indent=2))
        return 0
    print(f"Неизвестная команда: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
