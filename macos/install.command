#!/bin/bash
# Double-clickable macOS installer wrapper.
cd "$(dirname "$0")" || exit 1
bash ./install.sh "$@"
rc=$?
if [ "$rc" -ne 0 ]; then
    echo
    read -r -p "Installation failed. Press Enter to close..." _
fi
exit "$rc"
