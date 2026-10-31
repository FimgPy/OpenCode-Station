# OpenCode CMD Environment configuration
# Сделано Антоном Ковалкиным все права защищены.

# Prompt generator (Displays [env] D:\path> or D:\path>)
get_cmd_prompt() {
    local prefix=""
    if [ -n "$OPENCODE_ENV" ] && [ "$OPENCODE_ENV" != "default" ]; then
        prefix="[${OPENCODE_ENV}] "
    fi
    local p="$PWD"
    if [[ "$p" == "/mnt/d"* ]]; then
        p="D:${p#/mnt/d}"
    elif [[ "$p" == "/mnt/c"* ]]; then
        p="C:${p#/mnt/c}"
    elif [[ "$p" == "/mnt/"* ]]; then
        local drive=$(echo "$p" | cut -d/ -f3 | tr '[:lower:]' '[:upper:]')
        local rest=$(echo "$p" | cut -d/ -f4-)
        if [ -n "$rest" ]; then
            p="${drive}:/${rest}"
        else
            p="${drive}:"
        fi
    elif [[ "$p" == "/var/envs/"* ]]; then
        local env_sub=$(echo "$p" | cut -d/ -f4-)
        p="C:\\WSL\\envs\\${env_sub}"
    elif [[ "$p" == "/home/dev/workspace"* ]]; then
        p="D:\OpenCodeProjects${p#/home/dev/workspace}"
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
    PS1="$(get_cmd_prompt)> "
}
PROMPT_COMMAND=set_cmd_ps1
export PS1='$(get_cmd_prompt)> '

# Drive switching
d:() { 
    if [ -n "$OPENCODE_ENV" ] && [ "$OPENCODE_ENV" != "default" ]; then
        builtin cd "/mnt/d/OpenCodeProjects/$OPENCODE_ENV" 2>/dev/null || builtin cd /mnt/d/OpenCodeProjects
    else
        builtin cd /mnt/d/OpenCodeProjects/default 2>/dev/null || builtin cd /mnt/d/OpenCodeProjects
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
        d:
        return 0
    fi
    
    builtin cd "$target"
}

alias cd..='builtin cd ..'

# Classic CMD commands
cls() { clear; }

dir() {
    /usr/local/bin/cmd-dir "$@"
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
    win-open "$@"
}

open() {
    win-open "$@"
}

export() {
    if [ $# -eq 0 ]; then
        /usr/local/bin/export-win
    elif [[ "$1" == *"="* ]]; then
        builtin export "$@"
    else
        /usr/local/bin/export-win "$@"
    fi
}

linux() {
    /usr/local/bin/linux-dirs "$@"
}
ldir() {
    /usr/local/bin/linux-dirs "$@"
}
tree() {
    /usr/local/bin/cmd-tree "$@"
}

# Proxy management in live session
proxy() {
    local cfg="$HOME/.proxy_config"
    local default_no_proxy="localhost,127.0.0.1,::1,local.home"

    if [ ! -f "$cfg" ]; then
        echo 'PROXY_ENABLED="no"' > "$cfg"
        echo 'PROXY_URL=""' >> "$cfg"
    fi
    source "$cfg" 2>/dev/null || true

    case "$1" in
        on|ON)
            if [ -z "$PROXY_URL" ]; then
                echo "Адрес прокси не задан. Задайте прокси командой:"
                echo "  proxy set <http://хост:порт или socks5://хост:порт>"
                return 1
            fi
            export http_proxy="$PROXY_URL"
            export https_proxy="$PROXY_URL"
            export all_proxy="$PROXY_URL"
            export HTTP_PROXY="$PROXY_URL"
            export HTTPS_PROXY="$PROXY_URL"
            export ALL_PROXY="$PROXY_URL"
            export no_proxy="$default_no_proxy"
            export NO_PROXY="$default_no_proxy"
            sed -i 's/^PROXY_ENABLED=.*/PROXY_ENABLED="yes"/' "$cfg" 2>/dev/null || true
            echo "proxy = \"$PROXY_URL\"" > "$HOME/.curlrc" 2>/dev/null || true
            echo -e "\033[1;32m[✓] Прокси активирован:\033[0m $PROXY_URL"
            echo -e "\033[0;37mИсключения (local loopback):\033[0m $default_no_proxy"
            /usr/local/bin/myip
            ;;
        off|OFF)
            unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY no_proxy NO_PROXY
            sed -i 's/^PROXY_ENABLED=.*/PROXY_ENABLED="no"/' "$cfg" 2>/dev/null || true
            rm -f "$HOME/.curlrc" 2>/dev/null || true
            echo -e "\033[1;33m[✓] Прокси отключен.\033[0m Прямое интернет-подключение."
            /usr/local/bin/myip
            ;;
        set|SET)
            if [ -z "$2" ]; then
                echo "Использование: proxy set <url>"
                echo "Примеры:"
                echo "  proxy set http://127.0.0.1:10808"
                echo "  proxy set socks5://127.0.0.1:7890"
                echo "  proxy set socks5://user:pass@host:port"
                return 1
            fi
            local new_url="$2"
            echo 'PROXY_ENABLED="yes"' > "$cfg"
            echo "PROXY_URL=\"$new_url\"" >> "$cfg"
            export http_proxy="$new_url"
            export https_proxy="$new_url"
            export all_proxy="$new_url"
            export HTTP_PROXY="$new_url"
            export HTTPS_PROXY="$new_url"
            export ALL_PROXY="$new_url"
            export no_proxy="$default_no_proxy"
            export NO_PROXY="$default_no_proxy"
            echo "proxy = \"$new_url\"" > "$HOME/.curlrc" 2>/dev/null || true
            echo -e "\033[1;32m[✓] Прокси установлен и активирован:\033[0m $new_url"
            echo -e "\033[0;37mИсключения (local loopback):\033[0m $default_no_proxy"
            /usr/local/bin/myip
            ;;
        status|STATUS|"")
            echo "=================================================="
            echo "           Статус прокси в консоли                "
            echo "=================================================="
            if [ -n "$http_proxy" ]; then
                echo "Статус в сессии:  АКТИВЕН"
                echo "Адрес:            $http_proxy"
                echo "Исключения:       $default_no_proxy"
            else
                echo "Статус в сессии:  ОТКЛЮЧЕН (Прямое подключение)"
            fi
            echo "Сохраненный URL:  ${PROXY_URL:-не задан}"
            echo "--------------------------------------------------"
            echo "Команды:"
            echo "  proxy set <url>   -> Установить адрес прокси"
            echo "  proxy on          -> Включить прокси"
            echo "  proxy off         -> Отключить прокси"
            echo "  proxy status      -> Показать статус"
            echo "  myip              -> Проверить текущий внешний IP"
            echo "=================================================="
            ;;
        *)
            echo "Использование: proxy {set <url> | on | off | status}"
            ;;
    esac
}

myip() {
    /usr/local/bin/myip "$@"
}
ip() {
    /usr/local/bin/myip "$@"
}

# Environment management commands
env() {
    if [ $# -eq 0 ]; then
        /usr/local/bin/env-mgr list
    else
        case "$1" in
            list|ls|create|new|add|switch|use|enter|select|clean|reset|delete|remove|rm|del|purge|clear|clear-all|info|status|whoami|help|--help|-h|/?)
                /usr/local/bin/env-mgr "$@"
                ;;
            *)
                if [[ "$1" == *"="* ]]; then
                    /usr/bin/env "$@"
                else
                    /usr/local/bin/env-mgr "$@"
                fi
                ;;
        esac
    fi
}

envs() {
    /usr/local/bin/env-mgr list
}

switch() {
    /usr/local/bin/env-mgr switch "$@"
}

help() {
    if [ $# -eq 0 ]; then
        /usr/local/bin/help
    else
        case "$1" in
            dir|DIR) /usr/local/bin/cmd-dir /? ;;
            export|EXPORT) /usr/local/bin/export-win help ;;
            linux|LINUX) /usr/local/bin/linux-dirs --help ;;
            tree|TREE) /usr/local/bin/cmd-tree --help ;;
            env|ENV) /usr/local/bin/env-mgr help ;;
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
    
    if [ "$cmd_lower" != "$cmd" ] && type "$cmd_lower" >/dev/null 2>&1; then
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
