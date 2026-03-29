# Claude Code 오프라인 배포 솔루션

> [简体中文](../../README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | **한국어**

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.1-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)

자동 미러 감지, 지역 제한 우회 및 다국어 지원을 갖춘 지능형 Claude Code 오프라인 배포 솔루션입니다.

## 기능

- ✅ **GitHub Actions 자동 다운로드**: npm에서 최신 Claude Code를 자동으로 다운로드하고 패키징
- ✅ **다중 경로 자동 감지**: 하드코딩된 경로 없이 오프라인 패키지 자동 검색
- ✅ **범용 Node.js 설치**: nvm, apt 또는 직접 바이너리 다운로드 지원
- ✅ **유연한 배포 방식**: 오프라인 패키지, 온라인 다운로드 또는 직접 npm 설치
- ✅ **지능형 구성 관리**: 이전 구성 자동 정리
- ✅ **내장 클리닝 도구**: TMP 디렉토리 클리닝 스크립트 포함
- ✅ **🆕 미러 자동 감지**: 가장 빠른 다운로드 소스를 자동으로 테스트하고 선택
- ✅ **🆕 지역 제한 우회**: 첫 번째 시작 시 지역 확인을 건 너뛰는 자동 구성
- ✅ **🆕 제거 기능**: 백업 지원이 포함된 완전한 제거

---

## 🚀 빠른 시작（3가지 방법）

### 방법 1: 원라인 설치（권장, 인터넷 필요）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

### 방법 2: 오프라인 패키지 사용（인터넷 불필요）

1. [Releases](https://github.com/DeepTrial/claude-code-offline/releases)에서 `claude-offline-packages.tar.gz` 다운로드
2. 압축 해제 및 실행：

```bash
tar -xzf claude-offline-packages.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh
```

### 방법 3: 기존 오프라인 패키지

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

---

## ⚠️ 설치 후 필수 작업（중요）

**설치 후 API 키를 설정해야 합니다：**

### 1. 구성 파일 편집

```bash
nano ~/.claude/settings.json
```

### 2. 설정 업데이트

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

### 3. 구성 다시 로드

```bash
source ~/.bashrc
claude --version
```

> 💡 **팁**: Anthropic API에 직접 액세스할 수 없는 경우 `ANTHROPIC_BASE_URL`에 프록시를 설정하세요

---

## 자세한 사용 가이드

### 목차

- [자동 버전 업데이트](#자동-버전-업데이트)
- [미러 감지](#미러-감지)
- [지역 제한 우회](#지역-제한-우회)
- [고급 사용법](#고급-사용법)
- [제거](#제거)
- [문제 해결](#문제-해결)

## 자동 버전 업데이트

이 저장소에는 자동 버전 확인 및 업데이트 메커니즘이 포함되어 있습니다：

### GitHub Actions 자동 빌드

워크플로우가 자동으로：
1. **매일 확인**: 매일 UTC 00:00에 npm 레지스트리에서 새 버전 확인
2. **버전 비교**: npm 버전과 기존 GitHub Releases 비교
3. **스마트 빌드**: 새 버전이 감지된 경우에만 빌드
4. **자동 릴리스**: GitHub Release를 자동으로 생성

### 로컬 버전 체커

`check-update.sh`를 사용하여 업데이트 확인 및 다운로드：

```bash
# 대화형 확인
bash check-update.sh

# 확인만
bash check-update.sh --check-only

# 업데이트가 가능한 경우 다운로드 및 설치
bash check-update.sh --install
```

## 미러 감지

스크립트에는 자동으로 테스트하고 가장 빠른 다운로드 소스를 선택하는 지능형 미러 감지 시스템이 내장되어 있습니다.

### 지원되는 미러

| 유형 | 기본 | 미러 |
|------|------|------|
| **Node.js 바이너리** | `nodejs.org/dist/` | npmmirror, Tencent Cloud |
| **npm 레지스트리** | `registry.npmjs.org/` | `registry.npmmirror.com` |
| **nvm 설치 스크립트** | `raw.githubusercontent.com` | jsDelivr CDN, gitmirror |
| **GitHub API** | `api.github.com` | gitmirror, ghproxy, ghps.cc |

### 사용자 정의 미러

```bash
export NODE_MIRROR=https://your-mirror.com/node/
export NPM_MIRROR=https://your-registry.com
bash setup-claude-code.sh --auto-download
```

## 지역 제한 우회

Claude Code의 첫 번째 시작 시 지역 제한을 자동으로 우회하는 내장 구성입니다.

### 여전히 지역 문제가 발생하는 경우

올바른 API 엔드포인트（프록시 사용）를 확인：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-proxy-api-endpoint.com",
    "ANTHROPIC_API_KEY": "your-api-key"
  }
}
```

## 고급 사용법

### 스크립트 매개변수

| 매개변수 | 설명 |
|----------|------|
| `--offline-path PATH` | 오프라인 패키지 경로 지정 |
| `--auto-download` | GitHub Release에서 자동 다운로드 |
| `--force-download` | 강제로 다시 다운로드 |
| `--skip-mirror-test` | 미러 속도 테스트 건 너뛰기 |
| `--uninstall` | Claude Code 제거 |
| `--help, -h` | 도움말 표시 |

### 환경 변수

| 변수 | 설명 | 예시 |
|------|------|------|
| `NODE_MIRROR` | 사용자 정의 Node.js 미러 | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | 사용자 정의 npm 레지스트리 | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | 사용자 정의 GitHub 미러 | `https://hub.gitmirror.com/...` |

## 제거

```bash
bash setup-claude-code.sh --uninstall
```

포함 사항：
- `~/.claude/` 디렉토리 삭제
- `~/.claude.json` 삭제
- `.bashrc`에서 구성 제거
- 선택 사항：Node.js 및 nvm 제거
- 제거 전 자동 백업

## 문제 해결

### Node.js 설치 실패

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20
bash setup-claude-code.sh
```

### Claude 명령을 찾을 수 없음

```bash
source ~/.bashrc
# 또는
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API 연결 실패

확인 사항：
1. API 키가 올바른지
2. 네트워크가 `ANTHROPIC_BASE_URL`에 액세스할 수 있는지
3. 프록시 구성이 필요한지

## 라이선스

원본 Claude Code와 동일한 라이선스.

## 기여

Issues 및 Pull Requests를 환영합니다.

---

**참고**: Claude Code 및 로고는 Anthropic의 상표입니다. 이 프로젝트는 Anthropic과 제휴하지 않습니다.
