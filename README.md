# PocketBase CLI Skill

`PocketBase CLI Skill` 是一个面向 Codex 的正式发布 skill，用于安装、修复并调用自定义的 remote-only PocketBase CLI，在已部署的 PocketBase 实例上执行结构化远程运维与数据管理任务。

它的定位不是替代 PocketBase 原生二进制，也不是直接教 agent 拼 HTTP 请求，而是把你的自定义 CLI 作为统一执行面，提供更稳定的 schema 发现、前置检查和自动化调用路径。

## 核心能力

- 通过 `schema --json` 暴露机器可读的命令契约
- 通过 `preflight` 在执行前检查 base URL、认证状态和远程健康情况
- 覆盖 records、collections、files、logs、settings、backups 等远程工作流
- 在缺少可执行 CLI 时自动完成安装、构建与恢复
- 对高风险命令、敏感 token 输出和命令发现流程提供明确约束

## 适用范围

适用于：

- 已部署 PocketBase 实例的远程管理
- 需要稳定 JSON 输出的 agent/tooling 场景
- 通过自定义 CLI 执行日常运维、排障和数据操作

不适用于：

- 本地 PocketBase 进程管理
- `serve`、`migrate`、`update` 等本地二进制命令
- 绕过自定义 CLI 直接设计底层 HTTP 工作流的场景

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Ericsunsk/Pocketbase-CLI-Skill/main/install.sh)
```

默认安装目录：

```bash
~/.codex/skills/pocketbase-cli
```

安装完成后，可以作为 `$pocketbase-cli` skill 使用。

## 手动安装

```bash
git clone https://github.com/Ericsunsk/Pocketbase-CLI-Skill.git
cd Pocketbase-CLI-Skill
bash install.sh
```

## 安装脚本配置

安装脚本支持以下环境变量：

- `CODEX_HOME`
  默认值为 `~/.codex`
- `POCKETBASE_CLI_SKILL_TARGET_DIR`
  指定 skill 安装目录
- `POCKETBASE_CLI_SKILL_REPO_URL`
  覆盖 skill 仓库 Git 地址
- `POCKETBASE_CLI_SKILL_ARCHIVE_URL`
  覆盖 skill 仓库 tarball 地址
- `POCKETBASE_CLI_SKILL_NAME`
  覆盖安装后的 skill 目录名，默认是 `pocketbase-cli`

## 运行行为

安装后的 skill 会优先通过 `scripts/run-pocketbase-cli.sh` 解析 CLI 入口，并采用以下执行策略：

1. 优先使用显式提供的 `POCKETBASE_CLI_BIN`
2. 其次使用可验证的构建产物或已记录的安装位置
3. 最后才接受校验通过的 `pocketbase-cli` PATH 安装

如果当前没有可执行 CLI，skill 会尝试自动：

1. 复用本地已有的兼容源码仓库并构建
2. 否则从 `https://github.com/Ericsunsk/Pocketbase-CLI` 拉取源码
3. 安装依赖并构建 CLI
4. 重新执行原始命令

## 仓库结构

- `SKILL.md`
  skill 触发条件、工作流规则和执行约束
- `agents/openai.yaml`
  skill 展示与默认触发元数据
- `references/`
  补充工作流、命令面和常见任务模板
- `scripts/run-pocketbase-cli.sh`
  统一 CLI 调用入口
- `scripts/install-pocketbase-cli.sh`
  自定义 PocketBase CLI 的自动安装与构建入口
- `scripts/self-test.sh`
  关键安装与回退链路的回归检查
- `install.sh`
  当前 skill 的安装脚本

## 质量保证

仓库内置最小化回归检查：

```bash
bash scripts/self-test.sh
```

该脚本用于验证关键安装与回退链路是否保持可用，包括：

- 无效 `POCKETBASE_CLI_BIN` 的回退行为
- 不兼容 repo 候选的拒绝逻辑
- 自动安装后 `.runtime/repo_path` 的重新加载

## 相关仓库

- Skill 仓库：`https://github.com/Ericsunsk/Pocketbase-CLI-Skill`
- CLI 仓库：`https://github.com/Ericsunsk/Pocketbase-CLI`
