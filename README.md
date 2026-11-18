# ⚡ OpenCode Station v3.1

> **Изолированные среды OpenCode, веб-панель управления, встроенный терминал и менеджер прокси.**
> Две отдельные сборки: **Windows** и **macOS** (плюс Linux). Общее ядро, но разные установщики и документация.
> *Сделано Антоном Ковалкиным. Все права защищены.*

[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-blue?logo=windows)](#-windows)
[![macOS](https://img.shields.io/badge/macOS-11%2B-black?logo=apple)](#-macos)
[![Linux](https://img.shields.io/badge/Linux-x86__64%20%7C%20arm64-orange?logo=linux)](#-linux)
[![License - MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 📦 Две версии — не один универсальный установщик

| | 🪟 Windows | 🍎 macOS |
|---|---|---|
| **Установщик** | `windows/setup.bat` | `macos/install.command` |
| **CLI-установка** | `windows/setup.bat` | `bash macos/install.sh` |
| **Запуск** | `start_gui.bat` | `start.command` |
| **Остановка** | `stop.bat` | `stop.command` |
| **Среда** | WSL (Ubuntu) | нативный macOS |
| **Данные** | `/var/envs` + `workspace\` | `~/Library/Application Support/OpenCodeStation` |
| **Документация** | [windows/README.md](windows/README.md) | [macos/README.md](macos/README.md) |

Готовые архивы собираются в `dist/`:

```bash
bash scripts/build_packages.sh
```

- `dist/OpenCode-Station-<ver>-Windows.zip`
- `dist/OpenCode-Station-<ver>-macOS.tar.gz`
- `dist/SHA256SUMS`

В каждом архиве — только свой установщик, свои ярлыки и общая папка `bin/`.
Windows-архив не содержит macOS-скриптов, macOS-архив — `.bat`-файлов.

---

## 🌟 Возможности

- 🔒 **Изолированные среды:** свой `machine-id`, `hostname`, `HOME`, `XDG_*`, конфиги, база сессий и рабочая папка.
  - Linux/WSL2 — `unshare` (mount/UTS), хост не меняется.
  - macOS и WSL1 — автоматический user-space режим (`HOME`/`XDG`).
- 🌐 **Прокси на каждую среду:** HTTP/HTTPS/SOCKS5/SOCKS5h, локальный мост для SOCKS5, `NO_PROXY` для loopback.
- 🛡️ **Строгий TLS-префайр:** MITM-прокси отсеивается до запуска модели; таймаут не считается MITM.
- 💻 **GUI:** среды, сессии, файловый проводник, веб-терминал `ttyd`, каталог проверенных прокси.
- 🧩 **Единое ядро:** `bin/station_core.py`; запуск/остановка — `bin/stationctl`.

---

## 🪟 Windows

```powershell
git clone https://github.com/FimgPy/OpenCode-Station.git
cd OpenCode-Station
windows\setup.bat
```

Подробно: **[windows/README.md](windows/README.md)**

- `start_gui.bat` — GUI `http://localhost:7682`
- `start_web.bat` — веб-терминал `http://localhost:7681`
- `start.bat` — консольный режим
- `stop.bat` — остановить всё

## 🍎 macOS

```bash
git clone https://github.com/FimgPy/OpenCode-Station.git
cd OpenCode-Station
bash macos/install.sh
```

Или распакуйте macOS-архив и дважды щёлкните **`install.command`**.

Подробно: **[macos/README.md](macos/README.md)**

- `start.command` — запуск
- `stop.command` — остановка
- `bin/stationctl status` — проверка

## 🐧 Linux

```bash
bash linux/install.sh
./linux/start.sh
```

Подробно: **[linux/README.md](linux/README.md)**

---

## 📁 Структура проекта

```text
OpenCode-Station/
├── windows/                  # 🪟 ТОЛЬКО Windows
│   ├── setup.bat             # установщик (WSL)
│   ├── install_wsl.sh        # бэкенд установщика
│   ├── start_gui.bat / start_web.bat / start.bat / stop.bat
│   └── README.md
├── macos/                    # 🍎 ТОЛЬКО macOS
│   ├── install.command       # установщик (двойной клик)
│   ├── install.sh            # установщик (CLI)
│   ├── start.command / stop.command
│   └── README.md
├── linux/                    # 🐧 ТОЛЬКО Linux
│   ├── install.sh / start.sh / stop.sh
│   └── README.md
├── bin/                      # общее ядро и утилиты
├── config/                   # общие конфиги
├── scripts/build_packages.sh # сборка двух архивов
├── dist/                     # готовые архивы + SHA256SUMS
├── terminal.html             # веб-панель
└── README.md                 # этот файл
```

---

## 🌐 Прокси и лимиты

```bash
bin/proxy-tool test http://IP:PORT
bin/proxy-tool set  http://IP:PORT
bin/myip
```

Проверка включает реальный TLS до `opencode.ai` и `models.opencode.ai`.
Прокси, подменяющий сертификат, отклоняется — именно он вызывает
`SELF_SIGNED_CERT_IN_CHAIN` у OpenCode.

> Бесплатные прокси нестабильны и быстро исчерпывают квоту.
> `429 FreeUsageLimitError` означает лимит бесплатной модели для внешнего IP
> (сброс — 00:00 UTC), а не ошибку станции.

Проверенные прокси и заметки — в [config/proxies_catalog.json](config/proxies_catalog.json).

---

## 📄 Лицензия

MIT. Автор: **Антон Ковалкин**. Все права защищены.
