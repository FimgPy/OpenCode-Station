# ⚡ OpenCode Station v3.0

> **Автономная рабочая станция OpenCode с изолированными средами, веб-панелью управления (GUI), встроенным веб-терминалом и менеджером прокси.**
> Работает на **Windows (WSL2)**, **Linux** и **macOS**.
> *Сделано Антоном Ковалкиным. Все права защищены.*

[![OS - Windows | Linux | macOS](https://img.shields.io/badge/OS-Windows%20%7C%20Linux%20%7C%20macOS-blue)](#)
[![Python - 3.8+](https://img.shields.io/badge/Python-3.8%2B-yellow?logo=python)](https://python.org)
[![OpenCode - v2.2.1](https://img.shields.io/badge/OpenCode-v2.2.1-7952b3)](https://opencode.ai)
[![License - MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 🌟 Ключевые возможности

- 🔒 **Изолированные среды:**
  - У каждой среды свой `machine-id`, `hostname`, `HOME`, `XDG_*` каталоги, база сессий и рабочая папка.
  - На Linux/WSL используется отдельное mount/UTS-пространство имён (`unshare`), хост-система не изменяется.
  - На macOS и в user-space режиме изоляция обеспечивается раздельными `HOME`/`XDG_*` и локальными конфигами OpenCode.

- 🌐 **Прокси для каждой среды отдельно:**
  - Поддержка **HTTP**, **HTTPS**, **SOCKS5**, **SOCKS5h**.
  - Локальный мост `opencode-proxy-bridge` для SOCKS5.
  - `NO_PROXY` для `127.0.0.1`, `localhost`, `::1` — RPC и локальные сервисы работают всегда.
  - **Строгая TLS-проверка перед включением прокси** (см. раздел «Прокси и TLS»).
  - Проверка внешнего IP и геолокации среды: команда `myip` или кнопка в GUI.

- 💻 **Веб-интерфейс (GUI):** `http://localhost:7682`
  - Среды и сессии: создание, переключение, очистка, удаление.
  - Файловый проводник с нативными путями Linux/macOS/Windows.
  - Встроенный веб-терминал (`ttyd`, порт 7681) с запуском OpenCode из бэкенда.
  - Управление прокси, каталог проверенных прокси, глобальный прокси-фолбэк.

- 🧩 **Единое ядро:** `bin/station_core.py` — общая логика путей, сред, сессий, прокси и процессов для всех платформ.

- 🚀 **Простые лаунчеры:**
  - Windows: `setup.bat`, `start_gui.bat`, `start_web.bat`, `start.bat`, `stop.bat`.
  - Linux/macOS: `./setup.sh`, `./start_gui.sh`, `./stop.sh`.

---

## 🖥️ Поддержка платформ

| Возможность | Windows (WSL2) | Linux | macOS |
|---|---|---|---|
| Изоляция `machine-id`/`hostname` | ✅ `unshare` | ✅ `unshare` | ⚠️ user-space (`HOME`/`XDG`) |
| Веб-GUI | ✅ | ✅ | ✅ |
| Веб-терминал (`ttyd`) | ✅ | ✅ | ✅ (`brew install ttyd`) |
| Прокси на среду | ✅ | ✅ | ✅ |
| Автоустановка | `setup.bat` | `./setup.sh` | `./setup.sh` |

**Требования:** Python 3.8+, `curl`, `bash`, `ttyd` (Linux/macOS), ядро OpenCode CLI.

> WSL1 также работает: изоляция автоматически переключается в user-space режим
> (`HOME`/`XDG`, без `unshare`). Для полной изоляции `machine-id`/`hostname`
> рекомендуется WSL2.

---

## 📁 Структура проекта

```text
OpenCode-Station/
├── bin/
│   ├── station_core.py           # Единое ядро (пути, среды, прокси, процессы)
│   ├── stationctl                # start|stop|restart|status
│   ├── env-mgr                   # Менеджер сред (CLI)
│   ├── opencode                  # Изолированный launcher OpenCode + proxy-preflight
│   ├── opencode-gui-server       # Бэкенд GUI и REST API
│   ├── opencode-proxy-bridge     # Локальный HTTP -> SOCKS5 мост
│   ├── proxy-tool                # Управление прокси и каталогом
│   ├── myip                      # Внешний IP и геолокация среды
│   └── patch-opencode.py         # Скрытие upsell-окон клиента
├── config/
│   ├── 00-opencode-init.sh       # Загрузка прокси/окружения при старте shell
│   ├── cmd_mode.sh               # CMD-режим (WSL/Linux)
│   ├── bashrc_template           # Шаблон профиля
│   ├── install_wsl.sh            # Установка в WSL (вызывается setup.bat)
│   ├── proxies_catalog.json      # Каталог проверенных прокси
│   └── ttyd_index.html           # Клиент веб-терминала
├── terminal.html                 # Веб-панель управления
├── setup.bat / start_gui.bat / start_web.bat / start.bat / stop.bat
├── setup.sh / start_gui.sh / stop.sh
└── README.md
```

---

## 🛠️ Установка и запуск

### Windows 10/11 (WSL2)

```powershell
git clone https://github.com/FimgPy/OpenCode-Station.git
cd OpenCode-Station
setup.bat
```

- `setup.bat` проверит WSL2/Ubuntu, установит зависимости и развернёт станцию.
- Запуск: **`start_gui.bat`** → откроется `http://localhost:7682`.
- Терминал без GUI: **`start_web.bat`** → `http://localhost:7681`.
- Остановка: **`stop.bat`**.

### Linux / macOS

```bash
git clone https://github.com/FimgPy/OpenCode-Station.git
cd OpenCode-Station
chmod +x setup.sh start_gui.sh stop.sh
./setup.sh          # установка (для системных пакетов может потребоваться sudo)
./start_gui.sh      # запуск GUI
./stop.sh           # остановка
```

Управление без GUI:

```bash
bin/stationctl status
bin/stationctl start --no-browser
bin/stationctl stop
```

---

## 📦 Каталог данных (state dir)

Станция сама выбирает каталог:

1. `OPENCODE_STATION_DATA`, если задан.
2. `/var/envs` — если существует и доступен на запись (совместимость с WSL/Linux-установкой).
3. Иначе переносимый каталог:
   - Linux: `${XDG_DATA_HOME:-~/.local/share}/opencode-station`
   - macOS: `~/Library/Application Support/OpenCode-Station`
   - Windows: `%LOCALAPPDATA%\OpenCode-Station`

В каталоге хранятся `manifest.json`, среды, сессии, каталог прокси и служебные файлы `run/`.

---

## 🕹️ Управление средами (CLI)

В терминале среды доступна утилита `env` (алиас `env-mgr`):

```bash
env                      # список сред и активная среда
env create <имя>         # создать изолированную среду
env switch <имя>         # переключиться
env clean [имя]          # очистить историю/кэш и перегенерировать machine-id
env delete <имя> [-w]    # удалить среду (-w — вместе с рабочей папкой)
env myip                 # внешний IP и геолокация
env proxy                # управление прокси
```

Запуск OpenCode в среде:

```bash
env switch my-env --run opencode
# или
opencode            # использует активную среду
OPENCODE_ENV=my-env opencode
```

---

## 🌐 Прокси и TLS

### Почему OpenCode падал с `SELF_SIGNED_CERT_IN_CHAIN`

Бесплатные публичные прокси часто перехватывают HTTPS (MITM) и подменяют сертификат.
Клиент OpenCode проверяет TLS-цепочку `opencode.ai` / `models.opencode.ai` и падает:

```text
SELF_SIGNED_CERT_IN_CHAIN: self signed certificate in certificate chain
```

Старая проверка «IP через `api.ipify.org`» такие прокси пропускала. В v3.0 перед установкой
прокси выполняется **строгая проверка TLS** на реальных endpoint'ах OpenCode.
Если цепочка не доверенная — прокси отклоняется с понятной ошибкой, а не ломает запуск.

### Команды

```bash
proxy list                 # каталог проверенных прокси
proxy test http://IP:PORT  # IP + геолокация + строгий TLS
proxy set http://IP:PORT   # установить для активной среды (с проверкой)
proxy on | proxy off       # включить/выключить для среды
proxy global http://IP:PORT  # глобальный фолбэк для сред без своего прокси
proxy global off
proxy clean                # удалить нерабочие записи каталога
```

Важно:

- Прокси среды имеет приоритет над глобальным.
- Глобальный прокси — только фолбэк для сред без `.proxy_config`, он не перезаписывает среды.
- `opencode` дополнительно делает `proxy-preflight`: при MITM-прокси он отключает прокси для
  этого запуска и печатает предупреждение, вместо аварийного завершения.

### Проверенные европейские прокси (2026-11-18)

| Прокси | Страна (выход) | Организация | TLS |
|---|---|---|---|
| `http://85.187.224.21:8080` | Болгария, Kardzhali | Technolux Ltd. | ✅ |
| `http://132.243.174.245:5002` | Швейцария, Rümlang | Alexhost SRL | ✅ |
| `http://91.107.186.23:8081` | США, Santa Clara | DigitalOcean (выход 209.38.159.236) | ✅ |

Все три проверены реальным запросом к модели OpenCode из изолированных сред.
`103.237.102.191:11111` (Германия, Franet) также проходит TLS-проверку, но нестабилен.

> Бесплатные прокси нестабильны: IP может исчезнуть в любой момент. Всегда проверяйте
> командой `proxy test <url>`. Лимиты бесплатной модели OpenCode считаются по внешнему IP:
> при исчерпании сервер отвечает `429 FreeUsageLimitError` (сброс — 00:00 UTC).
> На момент проверки швейцарский IP уже исчерпал квоту (429), немецкий отвечал —
> это подтверждает, что лимиты у прокси разные.

---

## 🩺 Диагностика

| Проблема | Решение |
|---|---|
| GUI не открывается | `bin/stationctl status`, лог: `<state>/run/gui.log` |
| Порт 7682/7681 занят | `bin/stationctl stop`, затем `start` |
| `ttyd не найден` | Linux: `sudo apt install ttyd`; macOS: `brew install ttyd` |
| Прокси отклонён | он перехватывает TLS либо недоступен — выберите другой |
| `429 FreeUsageLimitError` | исчерпан лимит бесплатной модели для внешнего IP, смените прокси/подождите сброса |
| Нет `python3` | установите Python 3.8+ |

Логи:

- GUI: `<state>/run/gui.log`
- Терминал: `<state>/run/ttyd.log`
- OpenCode: `~/.local/share/opencode/log/opencode.log` внутри среды.

---

## 📄 Лицензия и авторство

Проект разработан и поддерживается: **Антон Ковалкин**.
Распространяется под свободной лицензией [MIT](LICENSE).

*Все права защищены.*
