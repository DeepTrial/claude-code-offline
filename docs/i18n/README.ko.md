# Claude Code 오프라인 배포 솔루션

> [简体中文](../../README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | **한국어**

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.2-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)
[![Codex Offline](https://img.shields.io/badge/sister%20project-Codex%20Offline-blueviolet)](https://github.com/DeepTrial/codex-offline)

자동화된 Claude Code 오프라인 배포 솔루션: 매일 npm에서 최신 버전의 Claude Code를 가져와 **Linux와 Windows 듀얼 플랫폼 오프라인 패키지**를 빌드하고, **자동화된 설치 테스트**를 거쳐 GitHub Releases에 게시합니다. 미러 소스 자동 감지, 지역 제한 우회, 완전 오프라인 설치, Node.js 없는 환경을 지원합니다.

## ✨ 특징

- ✅ **매일 자동 빌드**: GitHub Actions가 매일 npm의 새 버전을 확인하여 자동으로 빌드하고 게시합니다
- ✅ **듀얼 플랫폼 패키지**: Linux x64(`tar.gz`) + Windows x64(`zip`, 네이티브 PowerShell 설치 프로그램)
- ✅ **테스트 게이트**: 모든 패키지는 릴리스 전에 깨끗한 환경(Node 없는 Ubuntu 컨테이너 / Windows runner)에서 전체 설치 + 시작 검증을 거칩니다. **테스트를 통과하지 못하면 릴리스하지 않습니다**
- ✅ **Node.js 불필요**: claude-code 2.x는 독립형 네이티브 바이너리입니다. 네이티브 바이너리가 감지되면 Node.js는 선택 사항입니다
- ✅ **네트워크 장애에 강함**: 온라인 작업 전 5초 사전 점검, 모든 npm/curl 호출에 타임아웃 적용, 실패 시 즉시 오류를 보고하고 해결 방법을 안내합니다. 더 이상 "멈춤"이 없습니다
- ✅ **무인 설치**: `--yes` / `--non-interactive` 모드로 스크립트와 CI에 적합합니다
- ✅ **미러 소스 자동 감지**: 자동으로 속도를 측정하여 가장 빠른 Node.js / npm / GitHub 미러를 선택합니다
- ✅ **지역 제한 우회**: 첫 실행 시 지역 확인을 건너뛰도록 자동으로 설정합니다
- ✅ **20개의 오프라인 Skills/Plugins**: 문서 처리, 디자인, 테스트, LSP, 멀티 에이전트 프레임워크 등
- ✅ **완전한 제거 기능**: 설정 백업을 포함한 철저한 제거
- ✅ **이전 버전 모두 보존**: Releases가 더 이상 자동으로 정리되지 않아 언제든 롤백할 수 있습니다

---

## 🚀 빠른 시작

### Linux / macOS / WSL

**방법 1: 한 줄 명령으로 설치(네트워크 필요)**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

**방법 2: 오프라인 패키지로 설치(네트워크 불필요)**

```bash
# Releases에서 claude-offline-packages-linux.tar.gz를 다운로드한 후:
tar -xzf claude-offline-packages-linux.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh --yes
```

**방법 3: 로컬에 이미 오프라인 패키지가 있는 경우**

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

### Windows(네이티브)

1. [Releases](https://github.com/DeepTrial/claude-code-offline/releases)에서 `claude-offline-packages-windows.zip`을 다운로드하여 압축 해제
2. `setup-claude-code.bat`을 더블 클릭하거나 PowerShell에서 실행:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -NonInteractive
```

설치 프로그램은 네이티브 `claude.exe`를 검증하고, 설정을 생성하고, `bin` 디렉터리를 사용자 PATH에 기록합니다(멱등). `-OfflinePath` / `-AutoDownload` / `-NonInteractive` / `-Uninstall` / `-ConfigOnly` 매개변수를 지원합니다.

---

## ⚠️ 설치 후 필수 작업(중요 단계)

**사용하려면 반드시 자신의 API 키를 설정해야 합니다:**

```bash
# Linux/macOS/WSL
nano ~/.claude/settings.json

# Windows에서는 메모장으로 %USERPROFILE%\.claude\settings.json을 여세요
```

자리 표시자 값을 교체합니다:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-api-endpoint.com",
    "ANTHROPIC_API_KEY": "sk-your-api-key-here"
  }
}
```

그런 다음 **새 터미널을 열고**(또는 `source ~/.bashrc` 실행) 확인합니다:

```bash
claude --version
```

> 💡 Anthropic API에 직접 연결할 수 없는 지역에서는 `ANTHROPIC_BASE_URL`을 프록시/중계 주소로 설정하세요.

---

## 📦 Release 구성

| 파일 | 플랫폼 | 설명 |
|------|--------|------|
| `claude-offline-packages-linux.tar.gz` | Linux x64 / WSL | 전체 오프라인 패키지(skills, jq, VSCode 확장 포함) |
| `claude-offline-packages-windows.zip` | Windows x64 | 네이티브 Windows 패키지(skills, jq.exe, PS1 설치 프로그램 포함) |
| `*.sha256` | - | 체크섬 파일: `sha256sum -c <file>.sha256` |

이전 Release는 **모두 보존**되며, 언제든 이전 버전을 다운로드하여 롤백할 수 있습니다.

---

## 🔄 자동화 파이프라인

```
check-version → build-offline-packages (linux) ─┐
              → build-windows-package (windows) ┴→ test-release-package → create-release
                                                  (ubuntu + windows 양쪽 테스트)   (첨부 파일 4개)
```

- **매일 확인**: UTC 00:00에 npm 최신 버전과 기존 Release를 비교하여 새 버전이 있을 때만 빌드합니다
- **매주 재빌드**: 매주 월요일 UTC 01:00에 전체 재빌드합니다
- **수동 트리거**: Actions → `Download Claude Code Offline Packages` → Run workflow(버전 지정/강제 재빌드 가능)
- **테스트 게이트**: 테스트 작업은 깨끗한 ubuntu:22.04 컨테이너(Node 없음)와 windows-latest에서 각각 구조 검증, `claude --version` 단언, 완전한 비대화형 설치를 실행하며, 모두 통과해야만 게시됩니다

로컬에서 수동으로 업데이트 확인:

```bash
bash check-update.sh              # 대화형
bash check-update.sh --check-only # 확인만
bash check-update.sh --install    # 다운로드 및 설치
```

---

## 🧩 내장 오프라인 Skills 및 Plugins(20개)

빌드 시 `skills/skills-manifest.json`에 따라 자동으로 다운로드되며, 설치 프로그램 실행 후 `~/.claude/`에 설치됩니다:

| 분류 | 내용 |
|------|------|
| **문서 처리** | docx, pdf, pptx, xlsx |
| **디자인** | frontend-design, algorithmic-art, canvas-design, theme-factory, web-artifacts-builder |
| **테스트** | webapp-testing(Playwright) |
| **도구** | skill-creator |
| **엔터프라이즈** | brand-guidelines, internal-comms, doc-coauthoring |
| **플러그인** | superpowers(TDD/디버깅/계획 워크플로 프레임워크), everything-claude-code(ECC: 에이전트 67개, 스킬 278개, 명령 94개), gitlab(자체 호스팅 인스턴스 지정 가능), clangd-lsp, python-lsp, context7* |

> \* context7은 패키지에 포함되어 있지만 `offline_compatible=false`로 표시되어 있습니다(문서를 가져오려면 네트워크가 필요). clangd-lsp / python-lsp는 설정만 포함하며, 머신에 별도로 clangd / pyright가 필요합니다.

---

## 🖥️ 플랫폼 지원

기본적으로 **linux-x64**와 **win32-x64**가 자동으로 빌드됩니다. 설치 프로그램은 네이티브 바이너리가 감지되면 Node.js를 건너뜁니다. Node.js ≥ 18(22 권장)은 Node wrapper로 폴백해야 할 때만 필요합니다.

다른 플랫폼(linux-arm64, darwin, musl)은 포크 후 workflow에서 플랫폼 패키지 이름을 수정하여 직접 빌드하거나, Release 페이지의 안내에 따라 `npm pack`으로 수동으로 패키지를 구성하세요.

---

## 🛠️ 고급 사용법

### 설치 스크립트 매개변수(bash)

| 매개변수 | 설명 |
|----------|------|
| `--offline-path PATH` | 오프라인 패키지 경로 지정 |
| `--auto-download` | GitHub Release에서 자동 다운로드 |
| `--force-download` | 강제로 다시 다운로드 |
| `--skip-mirror-test` | 미러 속도 테스트 건너뛰기 |
| `--yes, -y` | 모든 프롬프트에 자동으로 yes(완전 무인) |
| `--non-interactive` | 비대화형 모드, 기본 답변을 자동으로 사용 |
| `--config-only` | 설정 파일만 생성 |
| `--skills-only` | 오프라인 skills만 설치 |
| `--uninstall` | Claude Code 및 설정 제거 |
| `--help, -h` | 도움말 |

### 환경 변수(사용자 지정 미러)

| 변수 | 설명 | 예시 |
|------|------|------|
| `NODE_MIRROR` | Node.js 미러 | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | GitHub API 미러 | `https://hub.gitmirror.com/https://api.github.com` |

---

## 🧪 설치 패키지 테스트

CI에서 사용하는 테스트 스크립트는 로컬에서도 실행할 수 있습니다:

```bash
# Linux 패키지: 구조 검증 + 버전 단언 + Node 없는 깨끗한 컨테이너에서 엔드투엔드 설치
bash tests/test-linux-package.sh /path/to/claude-offline-packages 2.1.215
```

```powershell
# Windows 패키지: 바이너리 검증 + 설치 프로그램 + settings.json + PATH 레지스트리 단언
powershell -NoProfile -File tests\test-windows-package.ps1 `
  -PackageDir .\claude-offline-packages-windows -ExpectedVersion 2.1.215
```

---

## 🗑️ 제거

```bash
# Linux/macOS/WSL
bash setup-claude-code.sh --uninstall
```

```powershell
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -Uninstall
```

제거 전에 설정이 자동으로 백업되며, 설정 디렉터리, `.claude.json`, shell/PATH 설정의 완전한 정리가 포함됩니다.

---

## 🔧 문제 해결

### 네트워크 오류(더 이상 멈추지 않음)

설치 프로그램은 온라인 작업 전에 5초 연결 사전 점검을 수행하며, 실패 시 **즉시 오류를 보고**하고 해결 방법을 안내합니다:

- **`Network appears UNAVAILABLE`** — 네트워크/프록시(`HTTPS_PROXY`)를 확인하거나 미러를 변경하세요: `NPM_MIRROR=https://registry.npmmirror.com bash setup-claude-code.sh --auto-download`
- **`npm registry UNREACHABLE / GitHub UNREACHABLE`** — 해당 호스트에 대한 5초 프로브가 타임아웃되었습니다. 해당 호스트가 필요한 단계만 건너뛰거나 중단되며, 순수 오프라인 단계는 계속됩니다
- **`'npm ...' timed out after Ns`** — npm이 내장 타임아웃을 초과했습니다. 일반적으로 registry가 차단되었거나 프록시가 필요한 경우이므로 `NPM_MIRROR=...`로 다시 시도하세요

### Node.js가 없는 환경

claude-code 2.x는 Bun으로 컴파일된 독립형 네이티브 바이너리입니다. 사용 가능한 바이너리가 감지되면 설치 프로그램이 `Native binary detected, Node.js optional`을 출력하고 Node 설치를 건너뜁니다. Node 없이도 정상적으로 사용할 수 있습니다.

### Windows에서 tar.gz 압축 해제 후 claude가 시작되지 않음(WSL 시나리오)

Windows 압축 해제 도구(파일 탐색기, 7z 등)는 **symlink를 버리기** 때문에 Linux 패키지의 `.bin/claude`가 손실됩니다. 이 설치 프로그램은 자가 복구 기능이 있습니다: 실행할 때마다 `.bin/claude`를 **실제 런처 스크립트**로 다시 만들므로 WSL에서 `setup-claude-code.sh`를 다시 실행하면 됩니다. 네이티브 Windows에서는 `claude-offline-packages-windows.zip`을 직접 다운로드하세요.

### claude 명령을 찾을 수 없음

```bash
source ~/.bashrc   # 또는 새 터미널을 여세요
# 수동 PATH:
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API 연결 실패

1. `ANTHROPIC_API_KEY`가 올바른지 확인
2. 설정된 `ANTHROPIC_BASE_URL`에 네트워크로 접근할 수 있는지 확인
3. 프록시가 필요한지 확인

---

## 라이선스

원본 Claude Code 라이선스와 동일합니다.

## 기여

이 프로젝트를 개선하기 위한 Issue와 Pull Request를 환영합니다.

---

**참고**: Claude Code와 Claude 로고는 Anthropic의 상표입니다. 이 프로젝트는 Anthropic과 관련이 없습니다.
