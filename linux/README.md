# 🐧 OpenCode Station — Linux

Отдельная версия для Linux. Windows: `windows/setup.bat`, macOS: `macos/install.command`.

## Установка

```bash
chmod +x linux/install.sh linux/start.sh linux/stop.sh
./linux/install.sh
```

Скрипт проверит Python 3.8+, `curl`, скачает `ttyd` и OpenCode CLI,
инициализирует каталог данных и манифест.

## Запуск

```bash
./linux/start.sh     # GUI + терминал, http://localhost:7682
./linux/stop.sh      # остановить всё
./bin/stationctl status
```

## Данные

- `$OPENCODE_STATION_DATA`, если задан;
- `/var/envs`, если каталог существует и доступен на запись (совместимость);
- иначе `$XDG_DATA_HOME/opencode-station` (обычно `~/.local/share/opencode-station`).

## Изоляция

На Linux используется `unshare --mount --uts` с отдельными `machine-id`,
`hostname`, `HOME` и `XDG_*`. Хост-система не изменяется.

## Прокси

```bash
./bin/proxy-tool test http://IP:PORT
./bin/proxy-tool set  http://IP:PORT
./bin/myip
```

Строгая TLS-проверка до `opencode.ai` / `models.opencode.ai` отсеивает
MITM-прокси, вызывающие `SELF_SIGNED_CERT_IN_CHAIN`.

## Диагностика

| Проблема | Решение |
|---|---|
| `ttyd` не найден | `sudo apt install ttyd` |
| GUI не открывается | `./bin/stationctl status`; лог `<state>/run/gui.log` |
| Порт занят | `./linux/stop.sh`, затем `./linux/start.sh` |
| `429 FreeUsageLimitError` | квота IP исчерпана; смените прокси или подождите 00:00 UTC |
