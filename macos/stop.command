#!/bin/bash
# Double-clickable macOS stop wrapper.
cd "$(dirname "$0")" || exit 1
./bin/stationctl stop
rc=$?
echo
read -r -p "Press Enter to close..." _
exit "$rc"
