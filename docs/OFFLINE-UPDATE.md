# 离线环境升级设计：Claude Code 与 Skills

本文档说明在**完全离线**（或弱网）环境中，如何用一个新的离线包升级已有的
Claude Code 安装，如何选择性安装 Skills/Plugins，以及如何更新已安装的 Skills。

适用对象：通过本项目离线包（`claude-offline-packages-*`）安装的用户。

---

## 1. 升级模型

离线环境的升级链路是：

```
联网机器下载新 Release 包 → U盘/内网拷贝到离线机器 → 运行 update-offline.sh
```

关键设计：**就地升级（in-place upgrade）**。

首次安装时，`setup-claude-code.sh` 不会复制包内容，而是直接把解压目录登记进
`~/.bashrc` 的 PATH 块：

```bash
# >>> CLAUDE_CODE_SETUP >>>
export PATH="/opt/claude-offline-packages/node_modules/.bin:$PATH"
# <<< CLAUDE_CODE_SETUP <<<
```

因此升级 = **用新包内容替换同一个目录**，PATH、shell 配置、API 密钥
（`~/.claude/settings.json`）、会话数据（`~/.claude/projects` 等）全部不受影响。

升级流程（`update-offline.sh`）：

1. 从 `~/.bashrc` 的 PATH 块自动定位当前安装目录（也可 `--target` 指定）
2. 校验新包：结构、架构（拒绝把 ARM64 包装到 x64 机器）、SHA256（若旁边有 `.sha256`）
3. 冒烟测试新二进制（`--version` 能跑才继续；跨架构场景仅警告）
4. 把旧包整体备份到 `~/.claude/backups/claude-offline-packages-<旧版本>-<时间戳>`
5. 新包复制到原目录 → 重跑包内 `setup-claude-code.sh` 修复 launcher/配置
6. 按策略更新 Skills（见第 3 节）

任何一步失败都会自动用备份恢复原状。

---

## 2. 升级 Claude Code

### Linux / macOS / WSL

```bash
# 方式 A：直接给压缩包（推荐，带校验和验证）
bash update-offline.sh claude-offline-packages-linux-x86_64.tar.gz

# 方式 B：先解压，给目录
tar -xzf claude-offline-packages-linux-x86_64.tar.gz
bash claude-offline-packages/update-offline.sh ./claude-offline-packages

# 无人值守
bash update-offline.sh claude-offline-packages-linux-x86_64.tar.gz --yes
```

> 旧包（v2.1.x 早期）里没有 `update-offline.sh` 时，用新包里的那份即可：
> `bash <新包目录>/update-offline.sh <新包目录>`

常用参数：

| 参数 | 说明 |
|------|------|
| `--update-skills` | （默认）从新包更新**已安装过**的 skills |
| `--skills a,b,c` | 升级后按指定列表安装 skills |
| `--skip-skills` | 完全不碰 skills |
| `--target DIR` | 手动指定要升级的安装目录 |
| `--force` | 版本相同也强制重装 |
| `--rollback [DIR]` | 回滚到备份（默认最近一次） |
| `--list-backups` | 列出所有可回滚备份 |
| `--yes, -y` | 非交互 |

### Windows（原生）

Windows 包沿用「重跑安装器」模型（安装器是幂等的）：

1. 下载新版 `claude-offline-packages-windows-x86_64.zip` 并解压到**新目录**
2. 重跑安装器，指向新目录：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 `
  -OfflinePath .\claude-offline-packages-windows -NonInteractive
```

3. 安装器会把用户 PATH 指向新目录；确认 `claude --version` 正常后即可删除旧目录

Skills 的更新在 Git Bash 中执行（见第 3 节，命令与 Linux 一致）。

### 回滚

```bash
bash update-offline.sh --list-backups     # 查看备份
bash update-offline.sh --rollback          # 回滚到最近一次备份
bash update-offline.sh --rollback ~/.claude/backups/claude-offline-packages-2.1.215-20261122
```

回滚同样会重跑该版本自带的 setup 脚本修复配置。

---

## 3. Skills / Plugins 的选择性安装与更新

安装器 `skills/install-skills.sh` 维护一份安装状态文件
`~/.claude/skills-installed.json`，记录每个已安装条目的名称、类型
（skill/plugin）、插件键和来源包版本。这是「只更新装过的」的基础。

### 查看可装/已装

```bash
bash skills/install-skills.sh --list
```

```
NAME                         TYPE     STATUS     DESCRIPTION
----                         ----     ------     -----------
docx                         skill    installed  Word document creation...
pdf                          skill    available  PDF processing...
superpowers                  plugin   installed  Agentric skills framework...
```

### 指定安装哪些

```bash
# 只装 docx 和 pdf
bash skills/install-skills.sh --only docx,pdf

# 全装，但排除体积大的 ECC 插件
bash skills/install-skills.sh --exclude everything-claude-code

# 脚本里使用（跳过确认）
bash skills/install-skills.sh --only superpowers --yes
```

### 更新已安装的 skills

拿到新离线包后，只刷新**已经装过**的条目（不会把新包里其它 skill 一并装上）：

```bash
# 直接对新包里的 bundle 执行
bash <新包目录>/skills/install-skills.sh <新包目录>/skills/offline-skills --update --yes
```

`--update` 的行为：

- 读取 `~/.claude/skills-installed.json`（老版本安装器没有状态文件时，自动从
  `~/.claude/skills/` 与 `~/.claude/plugins/cache/` 目录结构推断）
- 对其中每个条目，若新包里存在同名目录则覆盖安装；plugin 会同时刷新
  `installed_plugins.json` 里的版本/SHA 登记
- 新包里**没有**的条目保留原样并提示 skipped

`update-offline.sh` 默认在升级后自动执行这一步（即 `--update-skills`）。

### 卸载单个 skill

skills 是普通目录，plugins 有注册表：

```bash
rm -rf ~/.claude/skills/<name>            # skill
# plugin：删除缓存后用 jq 从注册表移除
rm -rf ~/.claude/plugins/cache/<marketplace>/<name>
jq 'del(.plugins["<name>@<marketplace>"])' \
   ~/.claude/plugins/installed_plugins.json > /tmp/p.json && mv /tmp/p.json ~/.claude/plugins/installed_plugins.json
# 同步删除状态文件条目
jq 'del(.entries["<name>"])' ~/.claude/skills-installed.json > /tmp/s.json && mv /tmp/s.json ~/.claude/skills-installed.json
```

---

## 4. 常见问题

**Q: 升级会丢 API 密钥 / 历史会话吗？**
不会。配置在 `~/.claude/` 下，升级只替换包目录。`settings.json` 已存在时
setup 脚本也不会覆盖（只会备份后补齐缺失字段）。

**Q: 下载错架构的包会怎样？**
`update-offline.sh` 会检查 `package-info.json` 的 platform 字段：ARM64 包装到
x64 机器会直接拒绝；反之 x64 包装到 ARM64 机器会给出警告（需 emulation）。

**Q: 包损坏怎么办？**
把 `.sha256` 文件和包放在一起，`update-offline.sh` 会自动做
`sha256sum -c`，校验失败拒绝安装。也可以手动先验证：
`sha256sum -c claude-offline-packages-linux-x86_64.tar.gz.sha256`

**Q: 能跨多个版本升级吗？**
可以，没有中间版本要求——每个 Release 都是完整包。

**Q: 联网环境也想用这套流程？**
联网机器建议直接用 `check-update.sh --install`（自动选架构、下载、校验、安装），
或 `npm install -g @anthropic-ai/claude-code@latest`。
