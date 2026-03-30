# PocketBase CLI Command Surface

Use this file only when you need help selecting the right command family. Runtime schema is still the source of truth.

## Core discovery and state

- `schema`: machine-readable contract for commands, arguments, options, enums, and payload hints
- `info`: summary of current remote mode, config, auth state, and health
- `preflight`: readiness check for base URL, auth, and health
- `config`: persist `base_url`, `auth_collection`, and timeout defaults
- `history`, `undo`, `redo`: inspect or revert local config mutations
- `repl`: interactive session, mainly for manual debugging

## Authentication

- `auth login`: credential login, supports `--password-stdin`
- `auth login-browser`: loopback browser flow, supports `--no-open`
- `auth status`, `auth whoami`, `auth refresh`, `auth logout`

Use auth commands when the task is about session state, re-authentication, or identity inspection.

## Remote admin endpoints

- `settings`: read and patch settings, test S3/email, generate Apple client secrets
- `logs`: list logs, inspect log entries, aggregate stats
- `crons`: list cron jobs and trigger runs

Use these for operational work on the deployed instance itself.

## Data model management

- `collections list|get|create|update|ensure|delete|truncate|import|scaffolds`

Preferred choice:

- use `collections ensure` for idempotent automation
- use `collections get` or `list` before destructive changes

## Record operations

- auth flows: `auth-methods`, `auth-password`, `auth-oauth2`, `auth-refresh`, OTP and password-reset helpers
- CRUD: `list`, `get`, `create`, `update`, `delete`
- higher-level helpers: `find`, `upsert`, `delete-by-filter`, `impersonate`

Preferred choice:

- use `find` before mutation when target identity is uncertain
- use `upsert` when a filter can define uniqueness

## File helpers

- `files token`: fetch a temporary file token
- `files url`: construct a PocketBase file URL, with optional thumb/download/token behavior

Use these instead of assembling signed or tokenized URLs manually.

## Backups

- `backups list|create|upload|delete|download|restore`

Use dedicated backup commands instead of raw backup endpoints. Read schema before restore/delete because they are guarded.

## Batch and raw

- `batch run`: validated JSON batch requests for supported record CRUD operations
- `raw`: direct HTTP escape hatch for uncovered endpoints

Preferred choice:

- use `batch run` for supported record bulk operations
- use `raw` only when no dedicated wrapper exists
