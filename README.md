# PocketBase CLI Skill

`PocketBase CLI Skill` 是一个给 Codex 使用的正式发布 skill，用于安装、修复并调用自定义的 remote-only PocketBase CLI，在已部署的 PocketBase 实例上执行结构化远程操作。

## 核心能力

- 通过自定义 CLI 而不是手写 HTTP 请求执行远程 PocketBase 任务
- 使用 `schema --json` 做命令发现，使用 `preflight` 做执行前检查
- 覆盖 records、collections、files、logs、settings、backups 等常见远程工作流
- 在缺少可执行 CLI 时自动完成安装、构建与恢复

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Ericsunsk/Pocketbase-CLI-Skill/main/install.sh)
```

默认安装到：

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

## 运行方式

安装后的 skill 会优先通过 `scripts/run-pocketbase-cli.sh` 解析 CLI 入口；如果当前没有可执行 CLI，会优先复用本地兼容源码仓库并构建，否则从 `https://github.com/Ericsunsk/Pocketbase-CLI` 拉取源码并完成安装。

## 仓库内容

- `SKILL.md`
- `agents/openai.yaml`
- `references/`
- `scripts/`
- `install.sh`

## 开发检查

```bash
bash scripts/self-test.sh
```

## 相关仓库

- Skill 仓库：`https://github.com/Ericsunsk/Pocketbase-CLI-Skill`
- CLI 仓库：`https://github.com/Ericsunsk/Pocketbase-CLI`
