#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${POCKETBASE_CLI_SKILL_REPO_URL:-https://github.com/Ericsunsk/Pocketbase-CLI-Skill.git}"
ARCHIVE_URL="${POCKETBASE_CLI_SKILL_ARCHIVE_URL:-https://github.com/Ericsunsk/Pocketbase-CLI-Skill/archive/refs/heads/main.tar.gz}"
SKILL_NAME="${POCKETBASE_CLI_SKILL_NAME:-pocketbase-cli}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
TARGET_DIR="${POCKETBASE_CLI_SKILL_TARGET_DIR:-${CODEX_HOME}/skills/${SKILL_NAME}}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pocketbase-cli-skill-install.XXXXXX")"
SOURCE_DIR=""

cleanup() {
  rm -rf "${TMP_DIR}"
}

trap cleanup EXIT

log() {
  printf '[pocketbase-cli-skill-install] %s\n' "$*"
}

fetch_source() {
  if command -v git >/dev/null 2>&1; then
    log "Cloning ${REPO_URL}"
    git clone --depth 1 "${REPO_URL}" "${TMP_DIR}/repo" >/dev/null 2>&1
    SOURCE_DIR="${TMP_DIR}/repo"
    return 0
  fi

  if command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
    log "Downloading archive ${ARCHIVE_URL}"
    curl -fsSL "${ARCHIVE_URL}" | tar -xz -C "${TMP_DIR}"
    SOURCE_DIR="$(find "${TMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "${SOURCE_DIR}" ]] || return 1
    return 0
  fi

  return 1
}

copy_item() {
  local item="$1"

  if [[ -e "${TARGET_DIR}/${item}" ]]; then
    rm -rf "${TARGET_DIR:?}/${item}"
  fi

  cp -R "${SOURCE_DIR}/${item}" "${TARGET_DIR}/${item}"
}

fetch_source || {
  echo "Unable to fetch PocketBase CLI Skill. Install git, or both curl and tar." >&2
  exit 1
}

[[ -f "${SOURCE_DIR}/SKILL.md" ]] || {
  echo "Fetched source does not contain SKILL.md" >&2
  exit 1
}

mkdir -p "$(dirname "${TARGET_DIR}")"

if [[ -e "${TARGET_DIR}" ]]; then
  backup_dir="${TARGET_DIR}.bak.$(date +%Y%m%d%H%M%S)"
  log "Backing up existing install to ${backup_dir}"
  mv "${TARGET_DIR}" "${backup_dir}"
fi

mkdir -p "${TARGET_DIR}"

copy_item "SKILL.md"
copy_item "agents"
copy_item "references"
copy_item "scripts"

find "${TARGET_DIR}/scripts" -type f -name "*.sh" -exec chmod +x {} +

log "Installed to ${TARGET_DIR}"
log "You can now use the skill as \$pocketbase-cli"
