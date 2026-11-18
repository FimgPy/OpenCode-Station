#!/bin/bash
# Double-clickable macOS launcher.
cd "$(dirname "$0")" || exit 1
if [ ! -x bin/stationctl ]; then
    echo "[!] OpenCode Station is not installed yet. Run install.command first."
    read -r -p "Press Enter to close..." _
    exit 1
fi
./bin/stationctl start "$@"
rc=$?
if [ "$rc" -ne 0 ]; then
    echo
    echo "Log: $HOME/Library/Application Support/OpenCodeStation/run/gui.log"
    read -r -p "Press Enter to close..." _
fi
exit "$rc"
