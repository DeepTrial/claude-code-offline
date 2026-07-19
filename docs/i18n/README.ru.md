# Офлайн-развёртывание Claude Code

> [简体中文](../../README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md) | **Русский** | [日本語](README.ja.md) | [한국어](README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.2-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)

Автоматизированное решение для офлайн-развёртывания Claude Code: ежедневно загружает последнюю версию Claude Code из npm, собирает **офлайн-пакеты для двух платформ — Linux и Windows** — и публикует их в GitHub Releases после **автоматизированного тестирования установки**. Поддерживает автоматический подбор зеркал, обход региональных ограничений, полностью офлайн-установку и работу в среде без Node.js.

## ✨ Возможности

- ✅ **Ежедневные автоматические сборки**: GitHub Actions ежедневно проверяет npm на наличие новых версий, автоматически собирает и публикует пакеты
- ✅ **Пакеты для двух платформ**: Linux x64 (`tar.gz`) + Windows x64 (`zip`, нативный установщик PowerShell)
- ✅ **Контроль качества через тесты**: перед публикацией каждый пакет проходит полную установку и проверку запуска в чистых окружениях (контейнер Ubuntu без Node / Windows runner) — **без прохождения тестов релиз не публикуется**
- ✅ **Node.js не требуется**: claude-code 2.x — автономный нативный бинарный файл; при обнаружении нативного бинарника Node.js становится опциональным
- ✅ **Устойчивость к сбоям сети**: 5-секундная предварительная проверка перед выходом в сеть, таймауты у всех вызовов npm/curl, немедленные сообщения об ошибках с рекомендациями по устранению — больше никакого «зависания»
- ✅ **Автоматическая установка**: режимы `--yes` / `--non-interactive` для скриптов и CI
- ✅ **Автоматический подбор зеркал**: замер скорости и выбор самого быстрого зеркала Node.js / npm / GitHub
- ✅ **Обход региональных ограничений**: автоматическая настройка пропуска проверки региона при первом запуске
- ✅ **20 офлайн Skills/Plugins**: обработка документов, дизайн, тестирование, LSP, мультиагентные фреймворки и многое другое
- ✅ **Полное удаление**: тщательная деинсталляция с резервным копированием конфигурации
- ✅ **Все прошлые релизы сохраняются**: Releases больше не очищаются автоматически — можно откатиться в любой момент

---

## 🚀 Быстрый старт

### Linux / macOS / WSL

**Способ 1: установка одной командой (требуется интернет)**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

**Способ 2: установка из офлайн-пакета (интернет не нужен)**

```bash
# После загрузки claude-offline-packages.tar.gz из Releases:
tar -xzf claude-offline-packages.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh --yes
```

**Способ 3: локальный офлайн-пакет уже есть**

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

### Windows (нативно)

1. Загрузите `claude-offline-packages-windows.zip` со страницы [Releases](https://github.com/DeepTrial/claude-code-offline/releases) и распакуйте архив
2. Дважды щёлкните `setup-claude-code.bat` или выполните в PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -NonInteractive
```

Установщик проверяет нативный `claude.exe`, создаёт конфигурацию и добавляет каталог `bin` в PATH пользователя (идемпотентно). Поддерживаются параметры `-OfflinePath` / `-AutoDownload` / `-NonInteractive` / `-Uninstall` / `-ConfigOnly`.

---

## ⚠️ Обязательно после установки (критический шаг)

**Для использования необходимо настроить собственный API-ключ:**

```bash
# Linux/macOS/WSL
nano ~/.claude/settings.json

# В Windows откройте %USERPROFILE%\.claude\settings.json в Блокноте
```

Замените значения-заполнители:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-api-endpoint.com",
    "ANTHROPIC_API_KEY": "sk-your-api-key-here"
  }
}
```

Затем **откройте новый терминал** (или выполните `source ~/.bashrc`) и проверьте:

```bash
claude --version
```

> 💡 В регионах без прямого доступа к Anthropic API укажите в `ANTHROPIC_BASE_URL` адрес вашего прокси/ретранслятора.

---

## 📦 Состав релиза

| Файл | Платформа | Описание |
|------|-----------|----------|
| `claude-offline-packages.tar.gz` | Linux x64 / WSL | Полный офлайн-пакет (включает skills, jq, расширения VSCode) |
| `claude-offline-packages-windows.zip` | Windows x64 | Нативный пакет для Windows (включает skills, jq.exe, установщик PS1) |
| `*.sha256` | - | Файлы контрольных сумм: `sha256sum -c <file>.sha256` |

Все прошлые релизы **сохраняются** — старую версию можно загрузить и откатиться в любой момент.

---

## 🔄 Конвейер автоматизации

```
check-version → build-offline-packages (linux) ─┐
              → build-windows-package (windows) ┴→ test-release-package → create-release
                                                  (тесты на ubuntu + windows)   (4 вложения)
```

- **Ежедневная проверка**: в 00:00 UTC сравнивается последняя версия в npm с существующими релизами; сборка запускается только при наличии новой версии
- **Еженедельная пересборка**: полная пересборка каждый понедельник в 01:00 UTC
- **Ручной запуск**: Actions → `Download Claude Code Offline Packages` → Run workflow (можно указать версию / принудительную пересборку)
- **Контроль качества**: тестовая задача выполняет структурные проверки, проверку `claude --version` и полную неинтерактивную установку в чистом контейнере ubuntu:22.04 (без Node) и на windows-latest; релиз публикуется только при успешном прохождении всех проверок

Локальная проверка обновлений вручную:

```bash
bash check-update.sh              # интерактивно
bash check-update.sh --check-only # только проверка
bash check-update.sh --install    # загрузить и установить
```

---

## 🧩 Встроенные офлайн Skills и Plugins (20 шт.)

Автоматически загружаются во время сборки согласно `skills/skills-manifest.json` и устанавливаются в `~/.claude/` при запуске установщика:

| Категория | Состав |
|-----------|--------|
| **Обработка документов** | docx, pdf, pptx, xlsx |
| **Дизайн** | frontend-design, algorithmic-art, canvas-design, theme-factory, web-artifacts-builder |
| **Тестирование** | webapp-testing (Playwright) |
| **Инструменты** | skill-creator |
| **Корпоративные** | brand-guidelines, internal-comms, doc-coauthoring |
| **Плагины** | superpowers (фреймворк рабочих процессов TDD / отладки / планирования), everything-claude-code (ECC: 67 агентов, 278 skills, 94 команды), gitlab (можно указать самостоятельно размещённый экземпляр), clangd-lsp, python-lsp, context7* |

> \* context7 упакован, но помечен как `offline_compatible=false` (для загрузки документации требуется интернет). clangd-lsp / python-lsp содержат только конфигурацию и требуют отдельно установленных clangd / pyright на машине.

---

## 🖥️ Поддержка платформ

По умолчанию автоматически собираются **linux-x64** и **win32-x64**. Установщик пропускает Node.js при обнаружении нативного бинарника; Node.js ≥ 18 (рекомендуется 22) требуется только при откате на Node wrapper.

Для других платформ (linux-arm64, darwin, musl) сделайте форк и измените имена платформенных пакетов в workflow для самостоятельной сборки или следуйте инструкциям на странице Releases, чтобы собрать пакет вручную с помощью `npm pack`.

---

## 🛠️ Расширенное использование

### Параметры скрипта установки (bash)

| Параметр | Описание |
|----------|----------|
| `--offline-path PATH` | Указать путь к офлайн-пакету |
| `--auto-download` | Автоматически загрузить из GitHub Release |
| `--force-download` | Принудительно загрузить заново |
| `--skip-mirror-test` | Пропустить замер скорости зеркал |
| `--yes, -y` | Автоматически отвечать yes на все запросы (полностью автоматический режим) |
| `--non-interactive` | Неинтерактивный режим, автоматически используются ответы по умолчанию |
| `--config-only` | Только создать файлы конфигурации |
| `--skills-only` | Только установить офлайн-skills |
| `--uninstall` | Удалить Claude Code и конфигурацию |
| `--help, -h` | Справка |

### Переменные окружения (пользовательские зеркала)

| Переменная | Описание | Пример |
|------------|----------|--------|
| `NODE_MIRROR` | Зеркало Node.js | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | Зеркало GitHub API | `https://hub.gitmirror.com/https://api.github.com` |

---

## 🧪 Тестирование установочных пакетов

Тестовые скрипты, используемые в CI, можно запускать и локально:

```bash
# Пакет Linux: структурные проверки + проверка версии + сквозная установка в чистом контейнере без Node
bash tests/test-linux-package.sh /path/to/claude-offline-packages 2.1.215
```

```powershell
# Пакет Windows: проверка бинарника + установщика + settings.json + утверждения PATH в реестре
powershell -NoProfile -File tests\test-windows-package.ps1 `
  -PackageDir .\claude-offline-packages-windows -ExpectedVersion 2.1.215
```

---

## 🗑️ Удаление

```bash
# Linux/macOS/WSL
bash setup-claude-code.sh --uninstall
```

```powershell
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -Uninstall
```

Перед удалением автоматически создаётся резервная копия конфигурации; выполняется полная очистка каталога конфигурации, `.claude.json` и настроек shell/PATH.

---

## 🔧 Устранение неполадок

### Сетевые ошибки (без зависаний)

Перед любым шагом, требующим сети, установщик выполняет 5-секундную проверку соединения и при сбое **немедленно сообщает об ошибке** с рекомендациями:

- **`Network appears UNAVAILABLE`** — проверьте сеть/прокси (`HTTPS_PROXY`) или смените зеркало: `NPM_MIRROR=https://registry.npmmirror.com bash setup-claude-code.sh --auto-download`
- **`npm registry UNREACHABLE / GitHub UNREACHABLE`** — 5-секундный пробник соответствующего хоста истёк по таймауту; шаги, требующие этого хоста, пропускаются или прерываются, чисто офлайн-шаги продолжаются
- **`'npm ...' timed out after Ns`** — npm превысил встроенный таймаут; обычно это означает, что registry заблокирован или нужен прокси — повторите с `NPM_MIRROR=...`

### Среда без Node.js

claude-code 2.x — автономный нативный бинарник, скомпилированный Bun. При обнаружении рабочего бинарника установщик выводит `Native binary detected, Node.js optional` и пропускает установку Node — всё работает и без Node.

### claude не запускается после распаковки tar.gz в Windows (сценарий WSL)

Средства распаковки Windows (Проводник, 7z и т. п.) **теряют символические ссылки**, из-за чего пропадает `.bin/claude` из пакета Linux. Этот установщик самовосстанавливается: при каждом запуске он пересоздаёт `.bin/claude` как **настоящий скрипт-загрузчик** — достаточно повторно запустить `setup-claude-code.sh` в WSL. Для нативного использования в Windows загружайте `claude-offline-packages-windows.zip`.

### Команда claude не найдена

```bash
source ~/.bashrc   # или откройте новый терминал
# PATH вручную:
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### Сбой подключения к API

1. Проверьте правильность `ANTHROPIC_API_KEY`
2. Проверьте, доступен ли по сети настроенный `ANTHROPIC_BASE_URL`
3. Уточните, требуется ли прокси

---

## Лицензия

Совпадает с лицензией оригинального Claude Code.

## Участие в разработке

Приветствуются Issue и Pull Request для улучшения проекта.

---

**Примечание**: Claude Code и логотип Claude являются товарными знаками Anthropic. Этот проект не связан с Anthropic.
