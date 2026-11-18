# Готовые сборки v3.1.2

| Файл | Для кого | Установщик внутри |
|---|---|---|
| `OpenCode-Station-3.1.2-Windows.zip` | Windows 10/11 (WSL) | `setup.bat` |
| `OpenCode-Station-3.1.2-macOS.tar.gz` | macOS 11+ | `install.command` / `install.sh` |

Контрольные суммы — в `SHA256SUMS`.

**Windows:** распакуйте zip и запустите `setup.bat`.
**macOS:** распакуйте tar.gz (двойной клик в Finder) и запустите `install.command`.

Это две разные сборки: в Windows-архиве нет macOS-скриптов, в macOS-архиве нет `.bat`.
Общее у них только ядро `bin/` и веб-панель `terminal.html`.

Пересобрать архивы:

```bash
bash scripts/build_packages.sh
bash scripts/verify_packages.sh
```
