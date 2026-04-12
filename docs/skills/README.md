# Claude Code 离线 Skills 指南

本文档列出了所有适用于离线部署的官方 Skills。

## 什么是 Skills

Skills 是 Claude Code 的插件系统，通过 `SKILL.md` 文件提供特定领域的指导和功能。离线可用的 Skills 是那些**不需要联网 API 调用**、只依赖本地文件操作或代码生成的技能。

## 离线可用 Skills 清单

### 文档处理类

| Skill | 描述 | 依赖 | 大小 |
|-------|------|------|------|
| `docx` | Word 文档创建、编辑、转换 | pandoc, docx-js, LibreOffice | ~500KB |
| `pdf` | PDF 处理、合并、分割、OCR | pypdf, pdf2image | ~300KB |
| `pptx` | PowerPoint 演示文稿处理 | python-pptx, pptxgenjs | ~400KB |
| `xlsx` | Excel 电子表格处理 | openpyxl, xlsx-populate | ~350KB |

### 设计与开发类

| Skill | 描述 | 依赖 | 大小 |
|-------|------|------|------|
| `frontend-design` | 高质量前端界面设计指导 | 无（纯指导） | ~50KB |
| `algorithmic-art` | 算法艺术生成 | 无（纯指导） | ~30KB |
| `canvas-design` | Canvas 图形设计 | 无（纯指导） | ~40KB |
| `theme-factory` | 主题生成 | 无（纯指导） | ~35KB |
| `web-artifacts-builder` | Web 产物构建 | 无（纯指导） | ~45KB |

### 测试与工具类

| Skill | 描述 | 依赖 | 大小 |
|-------|------|------|------|
| `webapp-testing` | 本地 Web 应用测试（Playwright） | playwright | ~200KB |
| `skill-creator` | 创建自定义 Skills 的指导 | 无（纯指导） | ~25KB |

### 企业应用类

| Skill | 描述 | 依赖 | 大小 |
|-------|------|------|------|
| `brand-guidelines` | 品牌指南应用 | 无（纯指导） | ~40KB |
| `internal-comms` | 内部沟通文档 | 无（纯指导） | ~35KB |
| `doc-coauthoring` | 文档协作 | 无（纯指导） | ~30KB |

## 需要联网的 Skills（**不适用于离线部署**）

以下 Skills 需要网络连接，不会包含在离线包中：

- `claude-api` - 需要调用 Claude API
- `mcp-builder` - MCP 服务器通常需要外部 API
- `slack-gif-creator` - 需要访问 Slack API

## Skills 安装位置

离线 Skills 安装到以下位置：

```
~/.claude/skills/
├── docx/
│   └── SKILL.md
├── pdf/
│   └── SKILL.md
├── ...
```

## 使用方法

安装后，Claude Code 会自动检测并使用这些 Skills。你可以通过以下方式验证：

```bash
# 查看已安装的 skills
ls ~/.claude/skills/

# 在 Claude Code 中使用
claude
# 然后询问: "帮我创建一个 Word 文档"
```

## 自定义 Skills

你也可以创建自己的离线 Skills：

1. 在 `~/.claude/skills/` 下创建新目录
2. 编写 `SKILL.md` 文件
3. 重启 Claude Code

参考 `skill-creator` 获取创建指南。
