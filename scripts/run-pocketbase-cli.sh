#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
default_repo="$(cd "${skill_dir}/.." && pwd)/Pocketbase-CLI"
install_script="${script_dir}/install-pocketbase-cli.sh"
runtime_dir="${skill_dir}/.runtime"
repo_state_file="${runtime_dir}/repo_path"

warn() {
  printf '[pocketbase-cli-runner] %s\n' "$*" >&2
}

path_cli_is_compatible() {
  local output

  if ! command -v pocketbase-cli >/dev/null 2>&1; then
    return 1
  fi

  if ! output="$(pocketbase-cli schema --json 2>/dev/null)"; then
    return 1
  fi

  [[ "${output}" == *'"tool":"pocketbase-cli"'* ]] &&
    [[ "${output}" == *'"mode":"remote-only"'* ]]
}

bin_path_is_compatible() {
  local bin_path="$1"
  local output

  if [[ ! -e "${bin_path}" ]]; then
    return 1
  fi

  if [[ "${bin_path}" == *.js ]]; then
    if ! output="$(node "${bin_path}" schema --json 2>/dev/null)"; then
      return 1
    fi
  else
    if ! output="$("${bin_path}" schema --json 2>/dev/null)"; then
      return 1
    fi
  fi

  [[ "${output}" == *'"tool":"pocketbase-cli"'* ]] &&
    [[ "${output}" == *'"mode":"remote-only"'* ]]
}

exec_bin_path() {
  local bin_path="$1"

  if [[ "${bin_path}" == *.js ]]; then
    exec node "${bin_path}" "$@"
  fi

  exec "${bin_path}" "$@"
}

exec_repo_bin_if_present() {
  local repo_dir="$1"
  local bin_path

  if [[ -z "${repo_dir}" ]]; then
    return 1
  fi

  bin_path="${repo_dir}/dist/bin.js"
  if [[ ! -f "${bin_path}" ]]; then
    return 1
  fi

  if ! bin_path_is_compatible "${bin_path}"; then
    warn "Ignoring incompatible repo candidate: ${repo_dir}"
    return 1
  fi

  exec node "${bin_path}" "$@"
}

load_state_repo() {
  if [[ -f "${repo_state_file}" ]]; then
    head -n 1 "${repo_state_file}"
    return 0
  fi

  printf '%s' ""
}

if [[ -n "${POCKETBASE_CLI_BIN:-}" ]]; then
  if [[ ! -e "${POCKETBASE_CLI_BIN}" ]]; then
    warn "Ignoring missing POCKETBASE_CLI_BIN: ${POCKETBASE_CLI_BIN}"
  elif bin_path_is_compatible "${POCKETBASE_CLI_BIN}"; then
    exec_bin_path "${POCKETBASE_CLI_BIN}" "$@"
  else
    warn "Ignoring incompatible POCKETBASE_CLI_BIN: ${POCKETBASE_CLI_BIN}"
  fi
fi

if path_cli_is_compatible; then
  exec pocketbase-cli "$@"
fi

repo_dir="${POCKETBASE_CLI_REPO:-${default_repo}}"
state_repo="$(load_state_repo)"

exec_repo_bin_if_present "${repo_dir}" "$@" || true
exec_repo_bin_if_present "${default_repo}" "$@" || true
exec_repo_bin_if_present "${state_repo}" "$@" || true

if [[ -x "${install_script}" ]]; then
  "${install_script}" >&2
  state_repo="$(load_state_repo)"
  exec_repo_bin_if_present "${repo_dir}" "$@" || true
  exec_repo_bin_if_present "${default_repo}" "$@" || true
  exec_repo_bin_if_present "${state_repo}" "$@" || true
fi

if path_cli_is_compatible; then
  exec pocketbase-cli "$@"
fi

echo "Unable to locate PocketBase CLI after automatic installation attempt." >&2
echo "Set POCKETBASE_CLI_BIN, provide a valid POCKETBASE_CLI_REPO, or install a compatible pocketbase-cli on PATH." >&2
echo "Install source: https://github.com/Ericsunsk/Pocketbase-CLI" >&2
exit 1
