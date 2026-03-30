---
name: pocketbase-cli
description: Use when installing, building, repairing, discovering, or executing commands through this custom remote-only PocketBase CLI project against deployed PocketBase instances, especially for schema-driven JSON automation and admin workflows.
metadata:
  short-description: Install and operate the custom PocketBase CLI
---

# PocketBase CLI

Use this skill when the task targets a deployed PocketBase instance and this custom remote-only CLI is the execution surface.

Do not use this skill for local PocketBase process management such as `serve`, `migrate`, `update`, or other embedded-binary workflows. This CLI is strictly remote-first.

Read [references/workflows.md](references/workflows.md) when you need the operating playbook. Read [references/command-surface.md](references/command-surface.md) only when you need help choosing the right command group. Read [references/prompt-templates.md](references/prompt-templates.md) only when the core workflow is already clear and you want a concrete mapping for one of the recurring record, collection, backup, file, logs, or settings tasks.

## Execution entrypoint

Use `./scripts/run-pocketbase-cli.sh` instead of guessing where the binary lives.

Before doing any real task, first verify that the CLI is installed and reachable.

Quick check:

```bash
./scripts/run-pocketbase-cli.sh --help
```

If no executable CLI is available yet, `./scripts/run-pocketbase-cli.sh` should attempt installation automatically before retrying.

Automatic install source:

`https://github.com/Ericsunsk/Pocketbase-CLI`

The preferred install flow is:

1. if `POCKETBASE_CLI_REPO` points at a compatible source repo, reuse it
2. otherwise install or update a shared checkout under `~/.local/share/pocketbase-cli`
3. run the repo installer when available, otherwise run `npm ci` or `npm install`
4. run `npm run build`
5. install the global `pocketbase-cli` command
6. retry the original CLI command

Only stop and report back to the user if auto-install fails because of environment, network, git, or npm errors.

Resolution order:

1. `POCKETBASE_CLI_BIN`
2. a verified `pocketbase-cli` on `PATH`
3. `POCKETBASE_CLI_REPO/dist/bin.js`
4. sibling repo `../Pocketbase-CLI/dist/bin.js`
5. last auto-installed repo recorded under `.runtime/repo_path`

If a compatible source repo exists but `dist/bin.js` does not, the install helper should build it before use.
The auto-install path is intentionally shared across agents on the same machine so one successful install can be reused.

## Core rules

1. Before use, verify that an executable CLI is available; if not, auto-install it from `https://github.com/Ericsunsk/Pocketbase-CLI` and retry.
2. Prefer `--json` for every non-REPL command.
3. Treat `schema --json` as the source of truth for command names, arguments, options, enums, confirmation flags, and `input_schema`.
4. Once you know the target command, switch from full-schema discovery to targeted schema lookup such as `schema records create --json`.
5. Run `preflight` before remote work. Add `--require-auth` when the chosen command requires auth.
6. Do not invent flags or payload shapes that are not present in the schema or the user's explicit data.
7. Prefer dedicated commands over `raw`. Use `raw` only when the schema shows no wrapper for the needed endpoint.

## Standard operating loop

1. Resolve the CLI:

```bash
./scripts/run-pocketbase-cli.sh --help
```

If this fails because no executable CLI is available, use the auto-install path first and only then surface installation failure:

`https://github.com/Ericsunsk/Pocketbase-CLI`

2. Discover the command:

```bash
./scripts/run-pocketbase-cli.sh schema --json
./scripts/run-pocketbase-cli.sh schema collections ensure --json
```

3. Check readiness:

```bash
./scripts/run-pocketbase-cli.sh --json preflight
./scripts/run-pocketbase-cli.sh --json preflight --require-auth
```

4. Execute the selected command in JSON mode.

5. Read the envelope:
- `ok`
- `result`
- `error`
- `http`
- `pagination`

If `ok` is `false` and `error.missing_prerequisite` is present, satisfy that prerequisite instead of retrying blindly.

## Auth and targeting

- Set or inspect the remote target with `config show|set|unset`.
- Base URL resolution order is: CLI flag, persisted config, `POCKETBASE_CLI_BASE_URL`, saved auth target.
- Use `auth login --password-stdin` for automation-safe login.
- Use `auth login-browser` or `auth login-browser --no-open` when interactive login is preferable.
- If auth stops matching the configured target, re-run `auth login` instead of forcing commands through mismatched state.

## JSON bodies and file uploads

- For object payloads, prefer `--stdin-json` or `--file`.
- Use `--data` only for small, non-sensitive inline JSON.
- Many mutating commands expose `input_schema` via `schema <path> --json`; inspect it before generating JSON.
- For file uploads, use repeatable `--binary-file <field>=<path>`.

Examples:

```bash
printf '{"name":"users","type":"base"}\n' | ./scripts/run-pocketbase-cli.sh --json collections ensure --stdin-json --output summary
printf '{"email":"demo@example.com"}\n' | ./scripts/run-pocketbase-cli.sh --json records create users --stdin-json
./scripts/run-pocketbase-cli.sh --json records create users --file payload.json --binary-file avatar=./avatar.png
```

## Safety rules

- Commands whose schema reports `confirmation_required: true` need explicit approval before using `--yes`.
- Prefer idempotent helpers such as `collections ensure` and `records upsert` when they fit the task.
- `raw` is anonymous by default. Add `--with-auth` only when the user intends an authenticated call.
- `files token` and tokenized `files url` output are redacted by default. Only use `--reveal-token` when the user explicitly asks for the sensitive token or signed URL value.
- Avoid REPL for repeatable automation unless the user explicitly wants an interactive debugging session.

## High-value command choices

- Use `info` for a quick remote state snapshot.
- Use `preflight` before admin actions.
- Use `collections ensure` for idempotent collection management.
- Use `records find`, `records upsert`, and `records delete-by-filter` for agent-style data workflows.
- Use `batch run` for validated bulk record CRUD requests.
- Use `files url` before assembling PocketBase file URLs by hand.
- Use `backups` commands for archive lifecycle instead of calling raw backup endpoints directly.

## Example task shapes

- "Show what this CLI can do" -> `schema --json`
- "Make sure the target is ready" -> `preflight` or `preflight --require-auth`
- "Create or update a collection safely" -> `schema collections ensure --json`, then `collections ensure`
- "Create or update a record with attachments" -> `schema records create|update|upsert --json`
- "Generate a file URL without leaking the token" -> `schema files url --json`, then `files url`
- "Hit an uncovered endpoint" -> inspect `raw` schema, then use `raw` as a last resort

If the request is phrased as an outcome instead of a command, map it to the nearest template in `references/prompt-templates.md` before executing.
