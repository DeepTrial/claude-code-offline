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
- ✅ **🆕 미러 자동 감지**: 가장 빠른 다운로드 소스를 자동으로 테스트하고 선택
- ✅ **🆕 지역 제한 우회**: 첫 번째 시작 시 지역 확인을 건 너뛰는 자동 구성
- ✅ **🆕 제거 기능**: 백업 지원이 포함된 완전한 제거

## 빠른 시작

```bash
# 방법 1: 자동 다운로드 (미러 감지 포함, 인터넷 필요)
bash setup-claude-code.sh --auto-download

# 방법 2: 지정된 오프라인 패키지 사용
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages

# 방법 3: 대화형 모드
bash setup-claude-code.sh
```

## 미러 자동 감지

스크립트에는 자동으로 테스트하고 가장 빠른 다운로드 소스를 선택하는 지능형 미러 감지 시스템이 내장되어 있습니다.

### 지원되는 미러

| 유형 | 기본 소스 | 미러 |
|------|----------|------|
| **Node.js 바이너리** | `nodejs.org/dist/` | npmmirror, Tencent Cloud |
| **npm registry** | `registry.npmjs.org/` | `registry.npmmirror.com` |
| **nvm 설치 스크립트** | `raw.githubusercontent.com` | jsDelivr CDN, gitmirror |
| **GitHub API** | `api.github.com` | gitmirror, ghproxy, ghps.cc |

## 지역 제한 우회

스크립트에는 Claude Code의 첫 번째 시작 시 지역 제한을 자동으로 우회하는 내장 구성이 있습니다.

## 전체 문서

자세한 내용은 다음 문서를 참조하세요:
- [简体中文](../../README.md)
- [English](README.en.md)

## 라이선스

원본 Claude Code와 동일한 라이선스.

---

**참고**: Claude Code 및 Claude 로고는 Anthropic의 상표입니다. 이 프로젝트는 Anthropic과 제휴하지 않습니다.
