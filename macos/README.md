# 🍎 OpenCode Station — macOS

Отдельная версия для macOS. **Не используйте Windows-установщик** (`setup.bat`) на Mac —
для macOS только `install.command` / `install.sh`.

## Требования

- macOS 11+ (Intel или Apple Silicon).
- Python 3.8+ (`xcode-select --install`, если `python3` не найден).
- `curl` (входит в macOS).
- Для встроенного веб-терминала — `ttyd` (ставится через Homebrew автоматически, если brew уже есть).

## Установка

1. Распакуйте архив.
2. Дважды щёлкните **`install.command`**.
   Если macOS блокирует запуск: правый клик → **Open** → **Open**, либо выполните в Терминале:

   ```bash
   cd ~/Downloads/OpenCode-Station-macOS
   xattr -dr com.apple.quarantine .
   bash install.sh
   ```

3. Установщик проверит Python/curl, поставит `ttyd` (если доступен Homebrew),
   скачает OpenCode CLI, создаст каталог данных и инициализирует `manifest.json`.

Проверка без изменений:

```bash
bash install.sh --check
```

Флаги: `--no-terminal` (не ставить ttyd), `--no-download` (не скачивать CLI),
`-y` (разрешить установку Homebrew/ttyd без вопросов).

## Запуск

- **`start.command`** — запуск GUI и терминала, откроется `http://localhost:7682`.
- **`stop.command`** — остановка всех процессов.
- CLI: `~/.local/bin/station status` (если `~/.local/bin` в `PATH`), либо `./bin/stationctl`.

## Где хранятся данные

```
~/Library/Application Support/OpenCodeStation/
```

Переопределение: `export OPENCODE_STATION_DATA=/путь/к/данным`.

Изоляция сред на macOS — user-space: у каждой среды свой `HOME`, `XDG_*`,
конфиги и база сессий OpenCode. `machine-id`/`hostname` хоста не меняются
(для этого нужен Linux/WSL2 с `unshare`).

## Прокси

```bash
./bin/proxy-tool test http://IP:PORT
./bin/proxy-tool set  http://IP:PORT
./bin/myip
```

Перед включением выполняется строгая TLS-проверка `opencode.ai` /
`models.opencode.ai`. Прокси с подменой сертификата отклоняется
(именно она вызывает `SELF_SIGNED_CERT_IN_CHAIN`).

## Диагностика

| Проблема | Решение |
|---|---|
| `python3: command not found` | `xcode-select --install` |
| `ttyd` не найден | `brew install ttyd` |
| Gatekeeper блокирует `.command` | `xattr -dr com.apple.quarantine .` |
| GUI не открывается | `./bin/stationctl status`; лог: `~/Library/Application Support/OpenCodeStation/run/gui.log` |
| Порт занят | `./stop.command`, затем `./start.command` |
| `429 FreeUsageLimitError` | бесплатная квота OpenCode исчерпана для внешнего IP; смените прокси или подождите 00:00 UTC |

## Отличия от Windows-версии

| | Windows | macOS |
|---|---|---|
| Установщик | `setup.bat` | `install.command` / `install.sh` |
| Среда выполнения | WSL (Ubuntu) | нативный macOS |
| Изоляция | `unshare` (WSL2) или user-space (WSL1) | user-space (`HOME`/`XDG`) |
| Терминал | `ttyd` в WSL | `ttyd` через Homebrew |
| Данные | `/var/envs` (WSL) + `workspace\` на диске | `~/Library/Application Support/OpenCodeStation` |
