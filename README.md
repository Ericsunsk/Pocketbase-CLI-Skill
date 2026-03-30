# PocketBase CLI Skill

`PocketBase CLI Skill` 是面向 Codex 的正式发布 skill，用于安装、发现并调用 remote-only PocketBase CLI，在已部署的 PocketBase 实例上执行结构化远程管理与数据操作。

## 定位

这个 skill 面向已部署的 PocketBase 环境，而不是本地 `serve`、`migrate`、`update` 一类嵌入式管理场景。它通过统一 CLI 入口提供稳定的 JSON 输出、Schema 驱动的命令发现，以及适合 agent 执行的安全工作流。

## 核心能力

- 通过 `schema --json` 获取命令契约，而不是依赖记忆或手写 HTTP 请求
- 通过 `preflight` 统一处理 base URL、认证状态和远端健康检查
- 覆盖 records、collections、files、logs、settings、backups 等常见远程任务
- 优先复用机器上已有的兼容 `pocketbase-cli`，缺失时自动完成安装与恢复
- 通过共享全局 CLI 安装，支持同一台机器上的多个 agent 复用同一份命令入口

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Ericsunsk/Pocketbase-CLI-Skill/main/install.sh)
```

默认安装目录：

```bash
~/.codex/skills/pocketbase-cli
```

安装完成后即可作为 `$pocketbase-cli` skill 使用。

## 手动安装

```bash
git clone https://github.com/Ericsunsk/Pocketbase-CLI-Skill.git
cd Pocketbase-CLI-Skill
bash install.sh
```

## 运行模型

安装后的 skill 通过 `scripts/run-pocketbase-cli.sh` 解析 CLI 入口，默认按以下顺序选择可执行目标：

1. `POCKETBASE_CLI_BIN`
2. 已在 `PATH` 上且兼容的全局 `pocketbase-cli`
3. 兼容的 repo 构建产物
4. 都没有时再自动安装

当自动安装触发时，CLI 会安装或更新到：

```bash
~/.local/share/pocketbase-cli
```

并同步安装全局 `pocketbase-cli` 命令，供多 agent 共享复用。

## 仓库结构

- `SKILL.md`
- `agents/openai.yaml`
- `references/`
- `scripts/`
- `install.sh`

## 验证

```bash
bash scripts/self-test.sh
```

## 适用场景

- 让 agent 通过统一 CLI 对远程 PocketBase 实例做只读检查或受控写操作
- 在多 agent 环境中复用一套全局安装好的 `pocketbase-cli`
- 需要稳定 JSON 输出、Schema 发现和预检流程的自动化任务

## 不适用场景

- 本地 PocketBase 进程生命周期管理
- 需要直接替代官方二进制的本地开发流程
- 与已部署 PocketBase 实例无关的通用 shell 自动化

## 相关仓库

- Skill 仓库：`https://github.com/Ericsunsk/Pocketbase-CLI-Skill`
- CLI 仓库：`https://github.com/Ericsunsk/Pocketbase-CLI`
