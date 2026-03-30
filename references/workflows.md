# PocketBase CLI Workflows

This file is the detailed playbook for using the CLI safely and predictably from an agent.

## 0. Installation gate

Only after you have decided the task should use this custom CLI, verify that an executable CLI is reachable:

```bash
./scripts/run-pocketbase-cli.sh --help
```

If this fails because no executable CLI is available yet, auto-install it from:

`https://github.com/Ericsunsk/Pocketbase-CLI`

Preferred sequence:

1. if a compatible local PocketBase CLI source checkout already exists, reuse it and build it
2. otherwise clone the repository
3. run `npm ci` when a lockfile exists, otherwise `npm install`
4. run `npm run build`
5. retry `./scripts/run-pocketbase-cli.sh --help`

Only stop and ask the user for help if that automatic install fails.

## 1. Discovery first

Do not hardcode command shapes from memory.

Use:

```bash
./scripts/run-pocketbase-cli.sh schema --json
./scripts/run-pocketbase-cli.sh schema <group> <command> --json
```

What to extract from the schema:

- `auth_required`
- `confirmation_required`
- `confirmation_flag`
- required arguments
- option conflicts
- enum `choices`
- `input_schema`
- notes and examples

Once the command is known, stop using the full schema dump and switch to targeted lookups.

## 2. Readiness check before execution

Use `preflight` before remote commands, especially when the task may fail because of missing config or auth.

```bash
./scripts/run-pocketbase-cli.sh --json preflight
./scripts/run-pocketbase-cli.sh --json preflight --require-auth
```

Interpretation:

- `ready: true` means the prerequisites passed.
- `missing_prerequisites` tells you what to fix next.
- `checks` breaks readiness into `base_url`, `auth`, and `health`.

Typical repair actions:

- missing `base_url` -> `config set base_url <url>`
- missing or mismatched auth -> `auth login` or `auth login-browser`
- health failure -> stop and surface the remote error instead of trying more writes

## 3. Auth bootstrap patterns

Automation-safe login:

```bash
printf '%s\n' "$PASSWORD" | ./scripts/run-pocketbase-cli.sh --json auth login --password-stdin admin@example.com
```

Browser login:

```bash
./scripts/run-pocketbase-cli.sh auth login-browser
./scripts/run-pocketbase-cli.sh auth login-browser --no-open
```

Use browser login when credentials should not be handled by the agent directly.

## 4. Payload handling rules

Preferred order for JSON bodies:

1. `--stdin-json`
2. `--file`
3. `--data`

Why:

- `--stdin-json` is best for generated payloads in pipelines.
- `--file` is best for larger checked-in or generated payload files.
- `--data` is the least safe for large or sensitive bodies.

For commands with collection-dependent payloads, the CLI schema gives only the envelope shape, not the business schema of your PocketBase collection. Get those fields from the user, from collection definitions, or from existing records before writing.

## 5. Safe mutation choices

Prefer these patterns:

- collection drift repair -> `collections ensure`
- create-or-update record by business key -> `records upsert`
- filtered lookup before mutation -> `records find`
- bulk record CRUD -> `batch run`

Avoid lower-level fallback unless required:

- use `raw` only when no dedicated wrapper exists
- do not use `raw --with-auth` unless the user intends an authenticated raw call

## 6. Destructive operations

If schema says `confirmation_required: true`, the command is intentionally guarded.

Rules:

- Do not add `--yes` unless the user intent is explicit and specific.
- If the task is ambiguous, ask before deleting, restoring, truncating, or otherwise causing irreversible side effects.
- When safe, prefer a read command first so the target is confirmed before the destructive call.

Common guarded commands include collection deletion, backup deletion, backup restore, record deletion by filter, and truncation-style operations.

## 7. Sensitive output handling

The CLI already redacts many secret-like values, but the agent still needs to be careful.

Rules:

- prefer redacted defaults
- only opt into `files url --reveal-token` when the user explicitly wants the sensitive value
- prefer `--password-stdin` over password argv
- do not echo secrets back into summaries unless the user explicitly requests them

## 8. Response reading

In JSON mode, inspect:

- `ok`
- `message`
- `result`
- `error`
- `http`
- `pagination`

Use `result` for business logic. `http` is useful for debugging remote status codes. `pagination` indicates whether more pages exist or whether `--all` was used.

## 9. Pagination and listing

For list commands, look for paging options in schema such as:

- `--page`
- `--per-page`
- `--all`

If the user asks for a complete dataset and `--all` exists, prefer it. If not, paginate deliberately and communicate that choice.

## 10. Regression check

When changing the runner, installer, or trigger instructions, run:

```bash
./scripts/self-test.sh
```

This covers the highest-value regressions:

- bad `POCKETBASE_CLI_BIN` fallback
- rejecting incompatible repo candidates
- auto-install fallback into a new `.runtime` repo
