# Claude Code Web Tool 离线使用说明

## 问题描述

在离线部署环境中，使用 Web Tool（网页获取功能）时可能会遇到以下错误：

```
Error: Unable to verify if domain github.com is safe to fetch. 
This may be due to network restrictions or enterprise security policies blocking claude.ai.
```

这是因为 Claude Code 的 Web Tool 默认需要通过 Anthropic 的服务器 (`claude.ai`) 进行域名安全检查，离线环境下无法连接导致失败。

## 解决方案

本项目已通过以下方式绕过此限制：

### 1. 环境变量配置（自动配置）

`~/.claude/claude-wrapper.sh` 中已自动设置：

```bash
export CLAUDE_CODE_WEB_FETCH_SKIP_SAFETY_CHECK=1
```

这会跳过域名安全检查，直接获取网页内容。

### 2. settings.json 配置

`~/.claude/settings.json` 中已添加：

```json
{
  "env": {
    "CLAUDE_CODE_WEB_FETCH_SKIP_SAFETY_CHECK": "1"
  }
}
```

## 使用方法

### 使用 Wrapper 脚本（推荐）

安装后，使用 `claude` 命令时会自动调用 wrapper 脚本：

```bash
# 这会使用 wrapper 脚本，自动包含环境变量
claude
```

### 手动设置环境变量

如果直接使用 `claude` 命令还有问题，可以手动设置：

```bash
export CLAUDE_CODE_WEB_FETCH_SKIP_SAFETY_CHECK=1
claude
```

### 完全禁用 Web Tool

如果你希望完全禁用 Web Tool（不获取任何网页内容），可以：

```bash
# 在 ~/.bashrc 或 ~/.zshrc 中添加
export CLAUDE_CODE_WEB_FETCH_DISABLED=1
```

然后重新加载配置：

```bash
source ~/.bashrc
```

## 离线环境下的 Web Tool 限制

在纯离线环境（无外网）中，Web Tool 功能有限：

| 功能 | 离线环境 | 有代理/API |
|------|---------|-----------|
| 获取公网网页 | ❌ 无法访问 | ✅ 正常 |
| 获取本地/内网网页 | ✅ 可以 | ✅ 正常 |
| 域名安全检查 | ❌ 已禁用 | ⚠️ 可选 |

## 替代方案

在完全离线的环境中，建议使用以下替代方案：

### 1. 手动下载网页内容

```bash
# 使用 curl 获取网页内容
curl -s https://example.com > /tmp/page.html

# 然后在 Claude Code 中读取文件
# "请分析 /tmp/page.html 的内容"
```

### 2. 使用本地文档

将需要的文档下载到本地：

```bash
mkdir -p ~/docs
curl -s https://docs.example.com/guide.md > ~/docs/guide.md
```

然后在 Claude Code 中引用这些本地文件。

### 3. 使用 Skills 的文档处理功能

已安装的离线 skills 可以处理本地文档：

- `docx` - 处理 Word 文档
- `pdf` - 处理 PDF 文档
- `pptx` - 处理 PowerPoint
- `xlsx` - 处理 Excel

## 故障排除

### 仍然看到安全检查错误

1. 确认使用 wrapper 脚本：
   ```bash
   which claude
   # 应该显示 alias 指向 wrapper
   ```

2. 手动验证环境变量：
   ```bash
   echo $CLAUDE_CODE_WEB_FETCH_SKIP_SAFETY_CHECK
   # 应该输出 1
   ```

3. 直接在命令行设置后启动：
   ```bash
   CLAUDE_CODE_WEB_FETCH_SKIP_SAFETY_CHECK=1 claude
   ```

### Web Tool 完全无法使用

如果仍然无法使用，可以完全禁用 Web Tool：

```bash
# 编辑 ~/.claude/claude-wrapper.sh
# 添加或修改以下行：
export CLAUDE_CODE_WEB_FETCH_DISABLED=1
```

这样 Claude 就不会尝试获取任何网页内容。

## 安全提示

⚠️ **警告**：跳过域名安全检查可能会带来安全风险：

- 可能获取到恶意网站的内容
- 可能暴露内部网络信息

**建议**：
- 仅在受信任的内网环境使用此配置
- 避免获取未知来源的网页
- 生产环境建议保持安全检查开启（需要联网）

## 相关配置参考

所有与离线部署相关的环境变量：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `DISABLE_AUTOUPDATER` | `1` | 禁用自动更新 |
| `CLAUDE_CODE_TELEMETRY` | `0` | 禁用遥测 |
| `DISABLE_TELEMETRY` | `1` | 禁用遥测 |
| `CLAUDE_CODE_SKIP_FIRST_RUN` | `1` | 跳过首次运行检查 |
| `CLAUDE_CODE_SKIP_ONBOARDING` | `1` | 跳过引导流程 |
| `CLAUDE_CODE_WEB_FETCH_SKIP_SAFETY_CHECK` | `1` | 跳过 Web 安全检查 |
| `CLAUDE_CODE_WEB_FETCH_DISABLED` | `1` | 完全禁用 Web Tool |
