# OpenCode Projects (Windows & WSL Shared Workspace)
# Сделано Антоном Ковалкиным все права защищены.

Рабочая папка проектов, синхронизированная между Windows (`D:\OpenCode-Station_Package\workspace`) и подсистемой WSL.

## Правила кроссплатформенности:

1. **Node.js (JavaScript / TypeScript)**:
   - Не копируйте `node_modules/` напрямую между Windows и Linux (в Linux компилируются бинарники `.so`, в Windows нужны `.dll`).
   - Для установки зависимостей на Windows запустите `npm install` прямо в папке проекта на Windows.

2. **Python**:
   - Папка виртуального окружения (`.venv`) должна быть отдельной для каждой ОС.
   - Зависимости фиксируются в `requirements.txt` или `pyproject.toml`.

3. **Служебные файлы**:
   - `node_modules`, `.venv`, `dist`, `build` добавлены в `.gitignore` по умолчанию.
   - Переносы строк (LF для кода, CRLF для bat-файлов) настроены через `.gitattributes`.
