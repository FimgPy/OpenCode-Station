#!/usr/bin/env bash
# Stop OpenCode Station (Linux only).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$HERE/bin" ]; then ROOT="$HERE"; else ROOT="$(dirname "$HERE")"; fi
exec python3 "$ROOT/bin/stationctl" stop
