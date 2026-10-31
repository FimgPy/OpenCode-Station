# System-wide proxy auto-loader
# Сделано Антоном Ковалкиным все права защищены.
if [ -f "$HOME/.proxy_config" ]; then
    . "$HOME/.proxy_config" 2>/dev/null
    if [ "$PROXY_ENABLED" = "yes" ] && [ -n "$PROXY_URL" ]; then
        export HTTP_PROXY="$PROXY_URL"
        export HTTPS_PROXY="$PROXY_URL"
        export http_proxy="$PROXY_URL"
        export https_proxy="$PROXY_URL"
        export ALL_PROXY="$PROXY_URL"
        export all_proxy="$PROXY_URL"
    fi
elif [ -f "/var/envs/global_proxy.json" ]; then
    GP_ENABLED=$(grep -o '"enabled": *true' /var/envs/global_proxy.json 2>/dev/null)
    GP_URL=$(grep -o '"url": *"[^"]*"' /var/envs/global_proxy.json 2>/dev/null | cut -d'"' -f4)
    if [ -n "$GP_ENABLED" ] && [ -n "$GP_URL" ]; then
        export HTTP_PROXY="$GP_URL"
        export HTTPS_PROXY="$GP_URL"
        export http_proxy="$GP_URL"
        export https_proxy="$GP_URL"
        export ALL_PROXY="$GP_URL"
        export all_proxy="$GP_URL"
    fi
fi

export NO_PROXY="localhost,127.0.0.1,::1,local.home"
export no_proxy="localhost,127.0.0.1,::1,local.home"

# Load OpenCode Station CMD mode for all interactive shells
if [[ $- == *i* ]] && [ -f /etc/profile.d/cmd_mode.sh ]; then
    . /etc/profile.d/cmd_mode.sh
fi
