# PocketBase CLI Prompt Templates

Use this file when the request is goal-oriented, such as "fix this collection", "update a user", or "restore a backup", and you want a reliable agent workflow without inventing steps.

Each template is intentionally short. Adapt names, filters, fields, and files to the actual task.

Assume the install gate and core workflow from `references/workflows.md` have already been applied. Use this file only when you need a concrete mapping from user intent to a recurring command pattern.

## Template 1: Bootstrap target and readiness

Use when the user has not confirmed whether the CLI target and auth are ready.

Prompt:

```text
Use $pocketbase-cli to verify the current PocketBase target is ready. First inspect the relevant schema if needed, then run JSON preflight checks, explain any missing prerequisites, and only continue with remote actions if the target is ready.
```

Expected flow:

1. `./scripts/run-pocketbase-cli.sh --json preflight`
2. If the next command needs auth, `./scripts/run-pocketbase-cli.sh --json preflight --require-auth`
3. If prerequisites are missing, stop and surface the exact repair action

## Template 2: Ensure a collection idempotently

Use when the user wants a collection created or updated safely.

Prompt:

```text
Use $pocketbase-cli to ensure the `users` collection matches the provided definition. First inspect `schema collections ensure --json`, then run `preflight --require-auth`, then execute the ensure command in JSON mode using stdin JSON. Prefer `--output summary` unless the full collection payload is needed.
```

Expected flow:

1. `schema collections ensure --json`
2. `--json preflight --require-auth`
3. `printf '<json>\n' | ./scripts/run-pocketbase-cli.sh --json collections ensure --stdin-json --output summary`

## Template 3: Create a record from structured data

Use when the user already knows the target collection and payload.

Prompt:

```text
Use $pocketbase-cli to create a record in the `users` collection from the provided JSON body. First inspect `schema records create --json`, then verify auth readiness, then create the record in JSON mode and summarize the created result.
```

Expected flow:

1. `schema records create --json`
2. `--json preflight --require-auth`
3. `printf '<json>\n' | ./scripts/run-pocketbase-cli.sh --json records create users --stdin-json`

## Template 4: Upsert a record by business key

Use when the request is "create if missing, otherwise update".

Prompt:

```text
Use $pocketbase-cli to upsert a record in `users` using the filter `email = "demo@example.com"`. Inspect `schema records upsert --json`, run auth preflight, then perform the upsert with stdin JSON. Prefer this over separate find and create/update steps unless the task requires manual inspection first.
```

Expected flow:

1. `schema records upsert --json`
2. `--json preflight --require-auth`
3. `printf '<json>\n' | ./scripts/run-pocketbase-cli.sh --json records upsert users --filter 'email = "demo@example.com"' --stdin-json`

## Template 5: Find first, then update or delete

Use when the target record is ambiguous and should be inspected before mutation.

Prompt:

```text
Use $pocketbase-cli to locate the target record in `users` first, confirm the match from the JSON result, then update it. Inspect the relevant record schemas, run auth preflight, list or find with the supplied filter, and only then execute the mutation.
```

Expected flow:

1. `schema records find --json` or `schema records list --json`
2. `--json preflight --require-auth`
3. `./scripts/run-pocketbase-cli.sh --json records find users --filter '<filter>'`
4. `schema records update --json`
5. `printf '<json>\n' | ./scripts/run-pocketbase-cli.sh --json records update users <record_id> --stdin-json`

For destructive follow-up:

- inspect the target first
- confirm the user's intent
- only then use the delete command, adding `--yes` only when the destructive intent is explicit

## Template 6: Create or update a record with file uploads

Use when the payload includes attachment fields.

Prompt:

```text
Use $pocketbase-cli to create or update a record in `users` with one or more files. First inspect the target record schema, then run auth preflight, then submit the JSON body plus repeatable `--binary-file <field>=<path>` flags.
```

Expected flow:

1. `schema records create --json` or `schema records update --json`
2. `--json preflight --require-auth`
3. `./scripts/run-pocketbase-cli.sh --json records create users --file payload.json --binary-file avatar=./avatar.png`

Notes:

- use `--file` or `--stdin-json` for the JSON body
- do not inline large file payload metadata into `--data` unless necessary

## Template 7: Generate a file URL safely

Use when the user wants a file URL and may or may not need a tokenized URL.

Prompt:

```text
Use $pocketbase-cli to build a file URL for the specified collection, record, and filename. Inspect `schema files url --json` first, then generate the URL in JSON mode. Do not reveal a tokenized URL unless the user explicitly asks for the token or signed value.
```

Expected flow:

1. `schema files url --json`
2. `./scripts/run-pocketbase-cli.sh --json files url <collection> <record_id> <filename>`

Sensitive variant:

- add `--with-token`
- only add `--reveal-token` on explicit user request

## Template 8: Backup inspection or download

Use when the task is to list, create, or download backups.

Prompt:

```text
Use $pocketbase-cli to inspect or download PocketBase backups safely. First inspect the specific backup command schema, run auth preflight, and then perform the requested backup operation in JSON mode. If downloading, preserve the chosen output path and report it clearly.
```

Expected flow:

1. `schema backups list --json` or `schema backups download --json`
2. `--json preflight --require-auth`
3. `./scripts/run-pocketbase-cli.sh --json backups list`
4. `./scripts/run-pocketbase-cli.sh --json backups download <name> --output <path>`

## Template 9: Restore or delete a backup

Use when the user explicitly wants a destructive backup action.

Prompt:

```text
Use $pocketbase-cli to restore or delete the specified backup, but treat it as destructive. Inspect the command schema first, verify auth readiness, confirm the exact target archive, and only then execute the guarded command with `--yes` if the user's intent is explicit.
```

Expected flow:

1. `schema backups restore --json` or `schema backups delete --json`
2. `--json preflight --require-auth`
3. `./scripts/run-pocketbase-cli.sh --json backups list`
4. `./scripts/run-pocketbase-cli.sh --json backups restore <name> --yes`

## Template 10: Logs and operational triage

Use when the user is debugging errors or wants operational insight.

Prompt:

```text
Use $pocketbase-cli to inspect logs for recent errors. First inspect the relevant logs schema, run auth preflight, then fetch logs in JSON mode and summarize the most relevant entries, HTTP details, or counts.
```

Expected flow:

1. `schema logs list --json` or `schema logs stats --json`
2. `--json preflight --require-auth`
3. `./scripts/run-pocketbase-cli.sh --json logs list ...`
4. optionally `./scripts/run-pocketbase-cli.sh --json logs stats`

## Template 11: Read or patch settings

Use when the task is to inspect or change PocketBase settings.

Prompt:

```text
Use $pocketbase-cli to inspect or patch remote settings. Inspect the target settings schema first, run auth preflight, then fetch or patch settings in JSON mode using stdin JSON for the patch body. If the task is testing S3 or email settings, use the dedicated test commands instead of a generic patch-only flow.
```

Expected flow:

1. `schema settings get --json`, `schema settings patch --json`, or test-command schema
2. `--json preflight --require-auth`
3. `./scripts/run-pocketbase-cli.sh --json settings get`
4. `printf '<json>\n' | ./scripts/run-pocketbase-cli.sh --json settings patch --stdin-json`

## Template 12: Raw endpoint fallback

Use only when the CLI has no dedicated wrapper for the endpoint.

Prompt:

```text
Use $pocketbase-cli to call a PocketBase endpoint through `raw` only if the schema shows there is no dedicated command for that operation. Inspect `schema raw --json` first, decide whether auth is required, run preflight, and then issue the request in JSON mode with the minimal necessary options.
```

Expected flow:

1. confirm no dedicated wrapper exists
2. `schema raw --json`
3. `--json preflight` or `--json preflight --require-auth`
4. `./scripts/run-pocketbase-cli.sh --json raw <METHOD> <PATH> [--with-auth]`
