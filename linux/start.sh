#!/usr/bin/env bash
# OpenCode Station GUI launcher (Linux only).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$HERE/bin" ]; then ROOT="$HERE"; else ROOT="$(dirname "$HERE")"; fi
exec python3 "$ROOT/bin/stationctl" start "$@"
