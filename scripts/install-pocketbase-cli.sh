#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
default_repo="$(cd "${skill_dir}/.." && pwd)/Pocketbase-CLI"
repo_url="https://github.com/Ericsunsk/Pocketbase-CLI.git"
runtime_dir="${skill_dir}/.runtime"
repo_state_file="${runtime_dir}/repo_path"

log() {
  printf '[pocketbase-cli-install] %s\n' "$*"
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

repo_dir_looks_compatible() {
  local dir="$1"
  local package_json

  if [[ -z "${dir}" || ! -f "${dir}/package.json" ]]; then
    return 1
  fi

  package_json="${dir}/package.json"
  grep -Eq '"name"[[:space:]]*:[[:space:]]*"pocketbase-cli"' "${package_json}"
}

record_repo_path() {
  local dir="$1"
  mkdir -p "${runtime_dir}"
  printf '%s\n' "${dir}" > "${repo_state_file}"
}

choose_repo_dir() {
  local preferred_repo="${POCKETBASE_CLI_REPO:-${default_repo}}"
  local state_repo=""
  local temp_repo=""

  if repo_dir_looks_compatible "${preferred_repo}" || [[ ! -e "${preferred_repo}" ]]; then
    printf '%s\n' "${preferred_repo}"
    return 0
  fi

  if repo_dir_looks_compatible "${default_repo}" || [[ ! -e "${default_repo}" ]]; then
    printf '%s\n' "${default_repo}"
    return 0
  fi

  if [[ -f "${repo_state_file}" ]]; then
    state_repo="$(head -n 1 "${repo_state_file}")"
    if repo_dir_looks_compatible "${state_repo}" || [[ -n "${state_repo}" && ! -e "${state_repo}" ]]; then
      printf '%s\n' "${state_repo}"
      return 0
    fi
  fi

  mkdir -p "${runtime_dir}"
  temp_repo="$(mktemp -d "${runtime_dir}/Pocketbase-CLI.XXXXXX")"
  printf '%s\n' "${temp_repo}"
}

install_dependencies() {
  local dir="$1"

  if [[ -f "${dir}/package-lock.json" ]]; then
    (cd "${dir}" && npm ci)
    return 0
  fi

  (cd "${dir}" && npm install)
}

repo_dir="$(choose_repo_dir)"
bin_js="${repo_dir}/dist/bin.js"

if [[ -f "${bin_js}" ]]; then
  record_repo_path "${repo_dir}"
  log "CLI build already available at ${bin_js}."
  exit 0
fi

if repo_dir_looks_compatible "${repo_dir}"; then
  log "Using existing repo at ${repo_dir}."
else
  if path_cli_is_compatible; then
    log "Compatible CLI already available on PATH."
    exit 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    log "git is required for automatic installation."
    exit 1
  fi

  log "Cloning ${repo_url} into ${repo_dir}."
  git clone "${repo_url}" "${repo_dir}"
fi

if ! command -v npm >/dev/null 2>&1; then
  log "npm is required for automatic installation."
  exit 1
fi

if [[ ! -f "${repo_dir}/package.json" ]]; then
  log "package.json not found in ${repo_dir}."
  exit 1
fi

log "Installing npm dependencies."
install_dependencies "${repo_dir}"

log "Building CLI."
(cd "${repo_dir}" && npm run build)

if [[ ! -f "${bin_js}" ]]; then
  log "Build completed but ${bin_js} was not created."
  exit 1
fi

record_repo_path "${repo_dir}"
log "CLI is ready at ${bin_js}."
