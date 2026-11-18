# 🪟 OpenCode Station — Windows

Отдельная версия для Windows 10/11. Станция работает внутри **WSL** (Ubuntu),
а `.bat`-файлы — нативные ярлыки Windows. **Не используйте macOS-установщик**
(`install.command`) на Windows.

## Требования

- Windows 10 (2004+) или Windows 11.
- WSL с Ubuntu (если WSL нет — `setup.bat` предложит установить).
- Интернет для загрузки OpenCode CLI.

## Установка

1. Распакуйте архив в папку без пробелов в пути (например, `D:\OpenCode-Station`).
2. Запустите **`setup.bat`** (двойным кликом).
   - Проверит WSL.
   - Установит пакеты, `ttyd`, OpenCode CLI.
   - Скопирует станцию в `/usr/local` и создаст `/var/envs`.
   - Подготовит `workspace\default` на диске Windows.

## Запуск

| Файл | Действие |
|---|---|
| **`start_gui.bat`** | GUI + веб-терминал, браузер `http://localhost:7682` |
| **`start_web.bat`** | только веб-терминал `http://localhost:7681` |
| **`start.bat`** | консольный режим (CMD-подобный shell в WSL) |
| **`stop.bat`** | остановить все процессы станции |

Все лаунчеры используют единый контроллер `stationctl` — отдельного «ручного»
запуска ttyd больше не требуется.

## Где хранятся данные

```
WSL:      /var/envs
Windows:  <папка установки>\workspace\<имя_среды>
```

Сменить каталог данных: `wsl -u dev -- env OPENCODE_STATION_DATA=/path python3 /usr/local/bin/stationctl start`.

## WSL1 и WSL2

- **WSL2** — полная изоляция: `unshare` + отдельные `machine-id`/`hostname`.
- **WSL1** — определяется автоматически, изоляция переключается в user-space
  (`HOME`/`XDG`, отдельные конфиги и сессии). Всё работает, кроме подмены
  `machine-id`/`hostname` хоста.

## Прокси

```bat
wsl -u dev -- /usr/local/bin/proxy-tool test http://IP:PORT
wsl -u dev -- /usr/local/bin/proxy-tool set  http://IP:PORT
wsl -u dev -- /usr/local/bin/myip
```

Или через GUI: вкладка **«Прокси и Сеть»**. Перед включением проверяется
настоящий TLS до `opencode.ai` / `models.opencode.ai`; MITM-прокси отклоняется.

## Диагностика

| Проблема | Решение |
|---|---|
| `WSL is not installed` | перезагрузитесь после `wsl --install -d Ubuntu` и запустите `setup.bat` снова |
| GUI не отвечает | `wsl -u dev -- python3 /usr/local/bin/stationctl status`; лог `/var/envs/run/gui.log` |
| Нет терминала | `wsl -u root -- apt-get install -y ttyd` |
| `python3` не найден | `wsl -u root -- apt-get install -y python3` |
| Прокси «не работает» | проверьте `proxy-tool test`; таймаут ≠ MITM, повторите или смените прокси |
| `429 FreeUsageLimitError` | исчерпана бесплатная квота IP; смените прокси или подождите 00:00 UTC |

## Отличия от macOS-версии

| | Windows | macOS |
|---|---|---|
| Установщик | `setup.bat` | `install.command` |
| Среда | WSL Ubuntu | нативный macOS |
| Данные | `/var/envs` + `workspace\` | `~/Library/Application Support/OpenCodeStation` |
| Терминал | `ttyd` в WSL | `ttyd` через Homebrew |
