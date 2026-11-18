#!/usr/bin/env bash
# OpenCode Station GUI launcher (Linux / WSL / macOS)
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$DIR/bin/stationctl" start "$@"
