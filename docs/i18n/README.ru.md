# Claude Code Автономное Развертывание

> [简体中文](../../README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md) | **Русский** | [日本語](README.ja.md) | [한국어](README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.1-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)

Интеллектуальное решение для автономного развертывания Claude Code с автоматическим обнаружением зеркал, обходом региональных ограничений и многоязычной поддержкой.

## Особенности

- ✅ **Автоматическая загрузка через GitHub Actions**: Автоматическая загрузка и упаковка последней версии Claude Code из npm
- ✅ **Автообнаружение путей**: Автоматический поиск автономных пакетов без жестко заданных путей
- ✅ **Универсальная установка Node.js**: Поддержка nvm, apt или прямой загрузки бинарных файлов
- ✅ **Гибкие методы развертывания**: Автономные пакеты, онлайн-загрузка или прямая установка npm
- ✅ **Умное управление конфигурацией**: Автоматическая очистка старых конфигураций
- ✅ **Встроенный инструмент очистки**: Включен скрипт очистки каталога TMP
- ✅ **🆕 Автообнаружение зеркал**: Автоматическое тестирование и выбор самого быстрого источника загрузки
- ✅ **🆕 Обход региональных ограничений**: Автоматическая настройка для пропуска проверки региона
- ✅ **🆕 Функция удаления**: Полное удаление с поддержкой резервного копирования

---

## 🚀 Быстрый старт (3 способа)

### Способ 1: Установка одной командой (рекомендуется, требуется интернет)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

### Способ 2: Использование автономного пакета (интернет не требуется)

1. Скачайте `claude-offline-packages.tar.gz` из [Releases](https://github.com/DeepTrial/claude-code-offline/releases)
2. Распакуйте и запустите:

```bash
tar -xzf claude-offline-packages.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh
```

### Способ 3: Существующий автономный пакет

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

---

## ⚠️ Обязательно после установки (Критически важно)

**После установки НЕОБХОДИМО настроить API ключ:**

### 1. Редактировать конфигурацию

```bash
nano ~/.claude/settings.json
```

### 2. Обновить настройки

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
    "ANTHROPIC_API_KEY": "sk-your-api-key-here",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-3-opus-20240229",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-3-sonnet-20240229",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-3-haiku-20240307"
  }
}
```

### 3. Перезагрузить конфигурацию

```bash
source ~/.bashrc
claude --version
```

> 💡 **Подсказка**: Если вы не можете напрямую получить доступ к API Anthropic, настройте прокси для `ANTHROPIC_BASE_URL`

---

## Подробное руководство по использованию

### Содержание

- [Автоматические обновления версий](#автоматические-обновления-версий)
- [Обнаружение источников зеркал](#обнаружение-источников-зеркал)
- [Обход региональных ограничений](#обход-региональных-ограничений)
- [Расширенное использование](#расширенное-использование)
- [Удаление](#удаление)
- [Устранение неполадок](#устранение-неполадок)

## Автоматические обновления версий

Этот репозиторий включает механизмы автоматической проверки и обновления версий:

### Автоматическая сборка GitHub Actions

Рабочий процесс автоматически:
1. **Ежедневная проверка**: Проверка npm registry на наличие новых версий ежедневно в 00:00 UTC
2. **Сравнение версий**: Сравнение версии npm с существующими GitHub Releases
3. **Умная сборка**: Сборка только при обнаружении новой версии
4. **Авто-релиз**: Автоматическое создание GitHub Release

### Локальный средство проверки версий

Используйте `check-update.sh` для проверки и загрузки обновлений:

```bash
# Интерактивная проверка
bash check-update.sh

# Только проверка
bash check-update.sh --check-only

# Загрузка и установка, если доступно обновление
bash check-update.sh --install
```

## Обнаружение источников зеркал

Скрипт включает интеллектуальное обнаружение источников зеркал, которое автоматически тестирует и выбирает самый быстрый источник загрузки.

### Поддерживаемые зеркала

| Тип | По умолчанию | Зеркала |
|-----|--------------|---------|
| **Бинарные файлы Node.js** | `nodejs.org/dist/` | npmmirror, Tencent Cloud |
| **Реестр npm** | `registry.npmjs.org/` | `registry.npmmirror.com` |
| **Скрипт nvm** | `raw.githubusercontent.com` | jsDelivr CDN, gitmirror |
| **GitHub API** | `api.github.com` | gitmirror, ghproxy, ghps.cc |

### Пользовательские зеркала

```bash
export NODE_MIRROR=https://your-mirror.com/node/
export NPM_MIRROR=https://your-registry.com
bash setup-claude-code.sh --auto-download
```

## Обход региональных ограничений

Встроенные конфигурации для обхода региональных ограничений Claude Code при первом запуске.

### Если по-прежнему возникают проблемы с регионом

Убедитесь в правильности конечной точки API (используя прокси):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-proxy-api-endpoint.com",
    "ANTHROPIC_API_KEY": "your-api-key"
  }
}
```

## Расширенное использование

### Параметры скрипта

| Параметр | Описание |
|----------|----------|
| `--offline-path PATH` | Указать путь к автономному пакету |
| `--auto-download` | Авто-загрузка из GitHub Release |
| `--force-download` | Принудительная повторная загрузка |
| `--skip-mirror-test` | Пропустить тест скорости зеркала |
| `--uninstall` | Удалить Claude Code |
| `--help, -h` | Показать справку |

### Переменные среды

| Переменная | Описание | Пример |
|------------|----------|--------|
| `NODE_MIRROR` | Пользовательское зеркало Node.js | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | Пользовательский реестр npm | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | Пользовательское зеркало GitHub | `https://hub.gitmirror.com/...` |

## Удаление

```bash
bash setup-claude-code.sh --uninstall
```

Включает:
- Удаление каталога `~/.claude/`
- Удаление файла `~/.claude.json`
- Удаление конфигураций из `.bashrc`
- Опционально: удаление Node.js и nvm
- Авто-резервное копирование перед удалением

## Устранение неполадок

### Ошибка установки Node.js

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20
bash setup-claude-code.sh
```

### Команда Claude не найдена

```bash
source ~/.bashrc
# или
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### Ошибка подключения к API

Проверьте:
1. API ключ правильный
2. Сеть может получить доступ к `ANTHROPIC_BASE_URL`
3. Необходима ли конфигурация прокси

## Лицензия

Та же лицензия, что и у оригинального Claude Code.

## Вклад

Приветствуются Issues и Pull Requests.

---

**Примечание**: Claude Code и логотип являются товарными знаками Anthropic. Этот проект не связан с Anthropic.
