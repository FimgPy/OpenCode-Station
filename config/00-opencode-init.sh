# OpenCode Station proxy auto-loader (portable)
# Made by Anton Kovalkin. All rights reserved.
STATION_DATA="${OPENCODE_STATION_DATA:-}"
if [ -z "$STATION_DATA" ]; then
    if [ -f /var/envs/manifest.json ]; then
        STATION_DATA=/var/envs
    else
        STATION_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-station"
    fi
fi
export OPENCODE_STATION_DATA="$STATION_DATA"

if [ -f "$HOME/.proxy_config" ]; then
    PROXY_ENABLED=""
    PROXY_URL=""
    . "$HOME/.proxy_config" 2>/dev/null
    if [ "$PROXY_ENABLED" = "yes" ] && [ -n "$PROXY_URL" ]; then
        export HTTP_PROXY="$PROXY_URL"
        export HTTPS_PROXY="$PROXY_URL"
        export http_proxy="$PROXY_URL"
        export https_proxy="$PROXY_URL"
        export ALL_PROXY="$PROXY_URL"
        export all_proxy="$PROXY_URL"
    else
        unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy
    fi
elif [ -f "$STATION_DATA/global_proxy.json" ]; then
    GP_ENABLED=$(grep -o '"enabled": *true' "$STATION_DATA/global_proxy.json" 2>/dev/null)
    GP_URL=$(grep -o '"url": *"[^"]*"' "$STATION_DATA/global_proxy.json" 2>/dev/null | cut -d'"' -f4)
    if [ -n "$GP_ENABLED" ] && [ -n "$GP_URL" ]; then
        export HTTP_PROXY="$GP_URL"
        export HTTPS_PROXY="$GP_URL"
        export http_proxy="$GP_URL"
        export https_proxy="$GP_URL"
        export ALL_PROXY="$GP_URL"
        export all_proxy="$GP_URL"
    else
        unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy ALL_PROXY all_proxy
    fi
fi

export NO_PROXY="localhost,127.0.0.1,::1,local.home"
export no_proxy="localhost,127.0.0.1,::1,local.home"

# CMD mode is a WSL convenience; on native Linux/macOS it is harmless but the
# prompt logic below falls back to a normal POSIX prompt.
if [[ $- == *i* ]] && [ -f "${OPENCODE_STATION_ROOT:-/usr/local}/config/cmd_mode.sh" ]; then
    . "${OPENCODE_STATION_ROOT:-/usr/local}/config/cmd_mode.sh"
elif [[ $- == *i* ]] && [ -f /etc/profile.d/cmd_mode.sh ]; then
    . /etc/profile.d/cmd_mode.sh
fi
