# PocketBase CLI Skill

这个仓库提供一个给 Codex 使用的 `pocketbase-cli` skill，用来操作你自定义的 remote-only PocketBase CLI 项目。

它解决的不是“直接调用 PocketBase API”，而是让 agent 优先通过你的 CLI 做：

- schema 驱动的命令发现
- `preflight` 前置检查
- records / collections / files / logs / settings / backups 等远程运维工作流
- 自定义 PocketBase CLI 的自动安装、构建、修复与调用

## 一键安装

直接运行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Ericsunsk/Pocketbase-CLI-Skill/main/install.sh)
```

默认会把 skill 安装到：

```bash
~/.codex/skills/pocketbase-cli
```

安装完成后，这个 skill 会在真正执行任务前检查你的自定义 PocketBase CLI 是否可用；如果没有可执行 CLI，会尝试自动：

1. 复用本地已有的 PocketBase CLI 源码仓库并构建
2. 或从 `https://github.com/Ericsunsk/Pocketbase-CLI` clone 后安装构建

## 手动安装

```bash
git clone https://github.com/Ericsunsk/Pocketbase-CLI-Skill.git
cd Pocketbase-CLI-Skill
bash install.sh
```

## 安装脚本支持的环境变量

- `CODEX_HOME`
  默认是 `~/.codex`
- `POCKETBASE_CLI_SKILL_TARGET_DIR`
  自定义 skill 安装目录
- `POCKETBASE_CLI_SKILL_REPO_URL`
  覆盖 skill 仓库 git 地址
- `POCKETBASE_CLI_SKILL_ARCHIVE_URL`
  覆盖 skill 仓库 tarball 地址
- `POCKETBASE_CLI_SKILL_NAME`
  覆盖 skill 目录名，默认是 `pocketbase-cli`

## 仓库内容

- `SKILL.md`
  触发说明和核心工作流
- `agents/openai.yaml`
  UI 和默认触发元数据
- `references/`
  workflow、命令面、prompt template
- `scripts/run-pocketbase-cli.sh`
  skill 调用 CLI 的统一入口
- `scripts/install-pocketbase-cli.sh`
  自动安装/构建你的 PocketBase CLI 项目
- `scripts/self-test.sh`
  skill 回归自测
- `install.sh`
  从 GitHub 一键安装这个 skill

## 自测

```bash
bash scripts/self-test.sh
```

当前自测覆盖：

- 坏掉的 `POCKETBASE_CLI_BIN` 回退
- 拒绝不兼容的 repo `dist/bin.js`
- 自动安装后重新读取 `.runtime/repo_path`

## 目标仓库

- Skill 仓库：`https://github.com/Ericsunsk/Pocketbase-CLI-Skill`
- CLI 仓库：`https://github.com/Ericsunsk/Pocketbase-CLI`
