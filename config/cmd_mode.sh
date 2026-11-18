# OpenCode CMD Environment configuration
# Сделано Антоном Ковалкиным все права защищены.

# Installed layout: /usr/local/bin.  Portable repo: $OPENCODE_STATION_ROOT/bin.
STATION_BIN="${OPENCODE_STATION_ROOT:+$OPENCODE_STATION_ROOT/bin}"
if [ ! -d "$STATION_BIN" ]; then
    STATION_BIN="/usr/local/bin"
fi

# Prompt generator (Displays [env] D:\path> or D:\path>)
get_cmd_prompt() {
    local prefix=""
    if [ -n "$OPENCODE_ENV" ] && [ "$OPENCODE_ENV" != "default" ]; then
        prefix="[${OPENCODE_ENV}] "
    fi
    # CMD-style drive letters only make sense inside WSL.  Native Linux and
    # macOS get a normal POSIX prompt.
    if [ -z "${WSL_DISTRO_NAME:-}" ]; then
        echo -n "${prefix}${PWD}> "
        return
    fi
    local p="$PWD"
    if [[ "$p" == "/mnt/d/OpenCode-Station_Package/workspace"* ]]; then
        p="D:\OpenCode-Station_Package\workspace${p#/mnt/d/OpenCode-Station_Package/workspace}"
    elif [[ "$p" == "/var/envs/"*"/workspace"* ]]; then
        local env_sub=$(echo "$p" | cut -d/ -f4)
        local rest=$(echo "$p" | cut -d/ -f6-)
        if [ -n "$rest" ]; then
            p="D:\OpenCode-Station_Package\workspace\\${env_sub}\\${rest}"
        else
            p="D:\OpenCode-Station_Package\workspace\\${env_sub}"
        fi
    elif [[ "$p" == "/var/envs/"* ]]; then
        local env_sub=$(echo "$p" | cut -d/ -f4-)
        p="C:\WSL\envs\\${env_sub}"
    elif [[ "$p" == "/mnt/d"* ]]; then
        p="D:${p#/mnt/d}"
    elif [[ "$p" == "/mnt/c"* ]]; then
        p="C:${p#/mnt/c}"
    elif [[ "$p" == "/home/dev/workspace/default"* ]]; then
        p="D:\OpenCode-Station_Package\workspace\default${p#/home/dev/workspace/default}"
    elif [[ "$p" == "/home/dev"* ]]; then
        p="C:\WSL\home\dev${p#/home/dev}"
    else
        p="C:\WSL${p}"
    fi
    p="${p//\//\\}"
    if [[ "$p" =~ ^[A-Z]:$ ]]; then
        p="${p}\\"
    fi
    echo -n "${prefix}${p}"
}

set_cmd_ps1() {
    local prompt_str="$(get_cmd_prompt)"
    prompt_str="${prompt_str//\\/\\\\}"
    PS1="${prompt_str}> "
}
PROMPT_COMMAND=set_cmd_ps1
export PS1='$(get_cmd_prompt)> '

# Drive switching
d:() {
    if [ -n "$OPENCODE_ENV" ] && [ "$OPENCODE_ENV" != "default" ]; then
        builtin cd "/mnt/d/OpenCode-Station_Package/workspace/$OPENCODE_ENV" 2>/dev/null || builtin cd /mnt/d/OpenCode-Station_Package/workspace 2>/dev/null || builtin cd /mnt/d
    else
        builtin cd /mnt/d/OpenCode-Station_Package/workspace/default 2>/dev/null || builtin cd /mnt/d/OpenCode-Station_Package/workspace 2>/dev/null || builtin cd /mnt/d
    fi
}
D:() { d:; }
c:() { builtin cd /mnt/c; }
C:() { builtin cd /mnt/c; }

# Enhanced cd command
cd() {
    if [ $# -eq 0 ]; then
        get_cmd_prompt
        echo
        return 0
    fi
    if [ "$1" = ".." ]; then
        builtin cd ..
        return $?
    fi
    if [ "$1" = "\"\"" ] || [ "$1" = "''" ]; then
        return 0
    fi
    
    local target="$1"
    target="${target//\\//}"
    
    if [[ "$target" =~ ^[Dd]:/(.*) ]]; then
        target="/mnt/d/${BASH_REMATCH[1]}"
    elif [[ "$target" =~ ^[Cc]:/(.*) ]]; then
        target="/mnt/c/${BASH_REMATCH[1]}"
    elif [[ "$target" =~ ^[A-Za-z]:/(.*) ]]; then
        local drv=$(echo "${target:0:1}" | tr '[:upper:]' '[:lower:]')
        target="/mnt/${drv}/${target:3}"
    elif [[ "$target" =~ ^[Dd]:$ ]]; then
        d:
        return 0
    elif [[ "$target" =~ ^[Cc]:$ ]]; then
        target="/mnt/c"
    elif [ "$target" = "~" ] || [ "$target" = "~/workspace" ]; then
        if [ -n "$OPENCODE_ENV" ] && [ "$OPENCODE_ENV" != "default" ] && [ -d "/var/envs/${OPENCODE_ENV}/workspace" ]; then
            target="/var/envs/${OPENCODE_ENV}/workspace"
        else
            target="/home/dev/workspace/default"
        fi
    fi
    
    builtin cd "$target"
}

alias cd..='builtin cd ..'

# Classic CMD commands
cls() { clear; }

dir() {
    \/cmd-dir "$@"
}

type() {
    if [ $# -eq 0 ]; then
        echo "Команда TYPE требует указания имени файла."
        return 1
    fi
    local f="$1"
    f="${f//\\//}"
    if [ -f "$f" ]; then
        cat "$f"
    elif [ -e "$f" ]; then
        cat "$f"
    else
        echo "Системе не удается найти указанный файл: $1"
        return 1
    fi
}

del() {
    if [ $# -eq 0 ]; then
        echo "Синтаксическая ошибка в имени файла или папки."
        return 1
    fi
    local files=()
    for item in "$@"; do
        item="${item//\\//}"
        files+=("$item")
    done
    rm -f "${files[@]}"
}
erase() { del "$@"; }

copy() {
    if [ $# -lt 2 ]; then
        echo "Неверный синтаксис команды COPY."
        return 1
    fi
    local src="${1//\\//}"
    local dst="${2//\\//}"
    cp -r "$src" "$dst"
}

move() {
    if [ $# -lt 2 ]; then
        echo "Неверный синтаксис команды MOVE."
        return 1
    fi
    local src="${1//\\//}"
    local dst="${2//\\//}"
    mv "$src" "$dst"
}

ren() {
    if [ $# -lt 2 ]; then
        echo "Неверный синтаксис команды REN."
        return 1
    fi
    local src="${1//\\//}"
    local dst="${2//\\//}"
    mv "$src" "$dst"
}
rename() { ren "$@"; }

md() {
    if [ $# -eq 0 ]; then
        echo "Неверный синтаксис команды MD."
        return 1
    fi
    local target="${1//\\//}"
    mkdir -p "$target"
}

rd() {
    if [ $# -eq 0 ]; then
        echo "Неверный синтаксис команды RD."
        return 1
    fi
    local target="${1//\\//}"
    rm -rf "$target"
}

ver() {
    local env_name="${OPENCODE_ENV:-default}"
    echo "OpenCode Command Prompt [Версия 2.2.1 · Среда: ${env_name}]"
    echo "Сделано Антоном Ковалкиным все права защищены."
}

explorer() {
    \/win-open "$@"
}
open() {
    \/win-open "$@"
}

export() {
    if [ $# -eq 0 ]; then
        builtin export
        return 0
    fi
    if [[ "$1" == *"="* ]]; then
        builtin export "$@"
        return $?
    fi
    case "$1" in
        all|ALL|select|SELECT|help|HELP|--help|-h|/?)
            \/export-win "$@"
            ;;
        *)
            \/export-win "$@"
            ;;
    esac
}

ai() {
    \/ai "$@"
}
ask() {
    \/ai "$@"
}

tree() {
    \/cmd-tree "$@"
}

linux() {
    \/linux-dirs "$@"
}
ldir() {
    \/linux-dirs "$@"
}

opencode() {
    \/opencode "$@"
}

proxy() {
    \/proxy-tool "$@"
    local rc=$?
    local cfg="$HOME/.proxy_config"
    local default_no_proxy="localhost,127.0.0.1,::1,local.home"
    if [ -f "$cfg" ]; then
        PROXY_ENABLED=""
        PROXY_URL=""
        . "$cfg" 2>/dev/null
        if [ "$PROXY_ENABLED" = "yes" ] && [ -n "$PROXY_URL" ]; then
            export http_proxy="$PROXY_URL"
            export https_proxy="$PROXY_URL"
            export all_proxy="$PROXY_URL"
            export HTTP_PROXY="$PROXY_URL"
            export HTTPS_PROXY="$PROXY_URL"
            export ALL_PROXY="$PROXY_URL"
        else
            unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
        fi
    fi
    export no_proxy="$default_no_proxy"
    export NO_PROXY="$default_no_proxy"
    return $rc
}

myip() {
    \/myip "$@"
}
ip() {
    \/myip "$@"
}

# Environment management commands
env() {
    if [ $# -eq 0 ]; then
        \/env-mgr list
    else
        case "$1" in
            list|ls|create|new|add|switch|use|enter|select|clean|reset|delete|remove|rm|del|purge|clear|clear-all|info|status|whoami|help|--help|-h|/?)
                \/env-mgr "$@"
                ;;
            *)
                if [[ "$1" == *"="* ]]; then
                    /usr/bin/env "$@"
                else
                    \/env-mgr "$@"
                fi
                ;;
        esac
    fi
}

envs() {
    \/env-mgr list
}

switch() {
    \/env-mgr switch "$@"
}

help() {
    if [ $# -eq 0 ]; then
        \/help
    else
        case "$1" in
            dir|DIR) \/cmd-dir /? ;;
            export|EXPORT) \/export-win help ;;
            linux|LINUX) \/linux-dirs --help ;;
            tree|TREE) \/cmd-tree --help ;;
            env|ENV) \/env-mgr help ;;
            proxy|PROXY) proxy status ;;
            myip|MYIP|ip|IP) myip ;;
            *) builtin help "$@" 2>/dev/null || echo "Справка по команде '$1' недоступна. Введите help для списка команд." ;;
        esac
    fi
}

# Command not found handler
command_not_found_handle() {
    local cmd="$1"
    local cmd_lower=$(echo "$cmd" | tr '[:upper:]' '[:lower:]')
    
    if [ "$cmd_lower" != "$cmd" ] && builtin type "$cmd_lower" >/dev/null 2>&1; then
        shift
        "$cmd_lower" "$@"
        return $?
    fi
    
    echo "'$cmd' не является внутренней или внешней"
    echo "командой, исполняемой программой или пакетным файлом."
    return 9009
}

# Uppercase aliases
alias DIR=dir
alias CLS=cls
alias CD=cd
alias TYPE=type
alias DEL=del
alias ERASE=del
alias COPY=copy
alias MOVE=move
alias REN=ren
alias RENAME=ren
alias MD=md
alias MKDIR=md
alias RD=rd
alias RMDIR=rd
alias HELP=help
alias VER=ver
alias AI=ai
alias ASK=ai
alias OPEN=open
alias EXPLORER=open
alias EXPORT=export
alias OPENCODE=opencode
alias PROXY=proxy
alias EXIT=exit
alias TREE=tree
alias LINUX=linux
alias LDIR=ldir
alias ENV=env
alias ENVS=envs
alias SWITCH=switch
alias MYIP=myip
alias IP=ip

# Case-insensitive tab completion
bind 'set completion-ignore-case on' 2>/dev/null || true
bind 'set show-all-if-ambiguous on' 2>/dev/null || true

# Startup banner
if [ -t 0 ] && [ -z "$OPENCODE_CMD_MODE_LOADED" ]; then
    export OPENCODE_CMD_MODE_LOADED=1
    echo "OpenCode Command Prompt [Версия 2.2.1]"
    echo "Сделано Антоном Ковалкиным все права защищены."
    echo ""
    echo "[OpenCode Command Prompt · D:\OpenCode-Station_Package\workspace]"
    echo "* Быстрый запуск: введите  ai <запрос>   или   opencode"
    echo "* Папки Linux   : введите  linux         (просмотр файлов и проектов в Linux)"
    echo "* Экспорт       : введите  export [all/select/маска] (экспорт файлов в Windows)"
    echo "* Список команд : введите  help          (dir, cls, cd, copy, del, tree, type, env, switch, myip...)"
    echo "* В Проводнике  : введите  open          (открыть текущую папку в Windows)"
    echo ""
fi
