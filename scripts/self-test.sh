#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skill_dir="$(cd "${script_dir}/.." && pwd)"
run_script_source="${script_dir}/run-pocketbase-cli.sh"
install_script_source="${script_dir}/install-pocketbase-cli.sh"

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/pbcli-selftest.XXXXXX")"
trap 'rm -rf "${tmp_root}"' EXIT

pass() {
  printf '[PASS] %s\n' "$*"
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "${haystack}" != *"${needle}"* ]]; then
    fail "${label}: expected output to contain '${needle}'"
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "${haystack}" == *"${needle}"* ]]; then
    fail "${label}: output unexpectedly contained '${needle}'"
  fi
}

setup_skill_copy() {
  local root="$1"
  local skill_copy="${root}/Pocketbase-CLI-SKILL"

  mkdir -p "${skill_copy}/scripts"
  cp "${run_script_source}" "${skill_copy}/scripts/run-pocketbase-cli.sh"
  cp "${install_script_source}" "${skill_copy}/scripts/install-pocketbase-cli.sh"
  chmod +x "${skill_copy}/scripts/run-pocketbase-cli.sh" "${skill_copy}/scripts/install-pocketbase-cli.sh"

  printf '%s\n' "${skill_copy}"
}

create_compatible_repo() {
  local repo_dir="$1"
  local help_text="$2"

  mkdir -p "${repo_dir}/dist"
  cat > "${repo_dir}/package.json" <<'EOF'
{
  "name": "pocketbase-cli"
}
EOF
  cat > "${repo_dir}/dist/bin.js" <<EOF
#!/usr/bin/env node
const args = process.argv.slice(2);

if (args[0] === "schema" && args[1] === "--json") {
  process.stdout.write('{"tool":"pocketbase-cli","mode":"remote-only"}\n');
  process.exit(0);
}

if (args.includes("--help")) {
  process.stdout.write("${help_text}\n");
  process.exit(0);
}

process.stdout.write(JSON.stringify({ argv: args }) + "\n");
EOF
  chmod +x "${repo_dir}/dist/bin.js"
}

create_incompatible_repo() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/dist"
  cat > "${repo_dir}/dist/bin.js" <<'EOF'
#!/usr/bin/env node
console.log("FAKE-CLI-RAN");
EOF
  chmod +x "${repo_dir}/dist/bin.js"
}

create_mock_toolchain() {
  local bin_dir="$1"
  local installed_help_text="$2"
  local real_node

  mkdir -p "${bin_dir}"
  real_node="$(command -v node)"
  ln -s "${real_node}" "${bin_dir}/node"

  cat > "${bin_dir}/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "clone" || $# -ne 3 ]]; then
  echo "unexpected git invocation: $*" >&2
  exit 1
fi

dest="$3"
mkdir -p "${dest}"
cat > "${dest}/package.json" <<'JSON'
{
  "name": "pocketbase-cli"
}
JSON
cat > "${dest}/package-lock.json" <<'JSON'
{
  "name": "pocketbase-cli",
  "lockfileVersion": 3
}
JSON
EOF
  chmod +x "${bin_dir}/git"

  cat > "${bin_dir}/npm" <<EOF
#!/usr/bin/env bash
set -euo pipefail

cmd="\${1:-}"
shift || true

case "\${cmd}" in
  prefix)
    if [[ "\${1:-}" == "-g" ]]; then
      mkdir -p "${bin_dir}/global-prefix"
      printf '%s\n' "${bin_dir}/global-prefix"
      exit 0
    fi
    echo "unexpected npm prefix invocation: \$*" >&2
    exit 1
    ;;
  ci|install)
    if [[ "\${1:-}" == "-g" ]]; then
      exit 0
    fi
    exit 0
    ;;
  run)
    if [[ "\${1:-}" != "build" ]]; then
      echo "unexpected npm run invocation: \$*" >&2
      exit 1
    fi
    mkdir -p dist
    cat > dist/bin.js <<'NODE'
#!/usr/bin/env node
const args = process.argv.slice(2);

if (args[0] === "schema" && args[1] === "--json") {
  process.stdout.write('{"tool":"pocketbase-cli","mode":"remote-only"}\\n');
  process.exit(0);
}

if (args.includes("--help")) {
  process.stdout.write("${installed_help_text}\\n");
  process.exit(0);
}

process.stdout.write(JSON.stringify({ argv: args }) + "\\n");
NODE
    chmod +x dist/bin.js
    exit 0
    ;;
  *)
    echo "unexpected npm invocation: \${cmd} \$*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${bin_dir}/npm"
}

create_compatible_path_cli() {
  local bin_dir="$1"
  local help_text="$2"

  cat > "${bin_dir}/pocketbase-cli" <<EOF
#!/usr/bin/env bash
set -euo pipefail

if [[ "\${1:-}" == "schema" && "\${2:-}" == "--json" ]]; then
  printf '%s\n' '{"tool":"pocketbase-cli","mode":"remote-only"}'
  exit 0
fi

if [[ " \$* " == *" --help "* ]]; then
  printf '%s\n' "${help_text}"
  exit 0
fi

printf '%s\n' "\$*"
EOF
  chmod +x "${bin_dir}/pocketbase-cli"
}

test_missing_env_bin_fallback() {
  local root skill_copy output home_dir mockbin sanitized_path

  root="${tmp_root}/test-missing-bin"
  home_dir="${root}/home"
  mkdir -p "${home_dir}"
  skill_copy="$(setup_skill_copy "${root}")"
  create_compatible_repo "${root}/Pocketbase-CLI" "default-help-ok"
  mockbin="${root}/mockbin"
  create_mock_toolchain "${mockbin}" "unused-help-ok"
  sanitized_path="${mockbin}:/usr/bin:/bin"

  output="$(
    env HOME="${home_dir}" \
      PATH="${sanitized_path}" \
      POCKETBASE_CLI_BIN=/definitely/missing \
      "${skill_copy}/scripts/run-pocketbase-cli.sh" --help 2>&1
  )"

  assert_contains "${output}" "Ignoring missing POCKETBASE_CLI_BIN" "missing env fallback"
  assert_contains "${output}" "default-help-ok" "missing env fallback"
  pass "missing POCKETBASE_CLI_BIN falls through to a compatible repo"
}

test_incompatible_repo_candidate_rejected() {
  local root skill_copy output home_dir mockbin sanitized_path

  root="${tmp_root}/test-incompatible-repo"
  home_dir="${root}/home"
  mkdir -p "${home_dir}"
  skill_copy="$(setup_skill_copy "${root}")"
  create_compatible_repo "${root}/Pocketbase-CLI" "default-help-ok"
  create_incompatible_repo "${root}/occupied-repo"
  mockbin="${root}/mockbin"
  create_mock_toolchain "${mockbin}" "unused-help-ok"
  sanitized_path="${mockbin}:/usr/bin:/bin"

  output="$(
    env HOME="${home_dir}" \
      PATH="${sanitized_path}" \
      POCKETBASE_CLI_REPO="${root}/occupied-repo" \
      "${skill_copy}/scripts/run-pocketbase-cli.sh" --help 2>&1
  )"

  assert_contains "${output}" "Ignoring incompatible repo candidate" "incompatible repo rejection"
  assert_not_contains "${output}" "FAKE-CLI-RAN" "incompatible repo rejection"
  assert_contains "${output}" "default-help-ok" "incompatible repo rejection"
  pass "runner rejects incompatible repo candidates before fallback"
}

test_global_path_cli_preferred() {
  local root skill_copy output home_dir mockbin sanitized_path

  root="${tmp_root}/test-path-cli-preferred"
  home_dir="${root}/home"
  mkdir -p "${home_dir}"
  skill_copy="$(setup_skill_copy "${root}")"
  create_compatible_repo "${root}/Pocketbase-CLI" "default-help-ok"
  mockbin="${root}/mockbin"
  create_mock_toolchain "${mockbin}" "unused-help-ok"
  create_compatible_path_cli "${mockbin}" "path-help-ok"
  sanitized_path="${mockbin}:/usr/bin:/bin"

  output="$(
    env HOME="${home_dir}" \
      PATH="${sanitized_path}" \
      "${skill_copy}/scripts/run-pocketbase-cli.sh" --help 2>&1
  )"

  assert_contains "${output}" "path-help-ok" "path cli preferred"
  assert_not_contains "${output}" "default-help-ok" "path cli preferred"
  pass "runner prefers compatible pocketbase-cli on PATH before repo fallbacks"
}

test_install_fallback_runtime_reload() {
  local root skill_copy mockbin output state_file state_repo shared_repo sanitized_path home_dir

  root="${tmp_root}/test-install-fallback"
  home_dir="${root}/home"
  mkdir -p "${home_dir}"
  skill_copy="$(setup_skill_copy "${root}")"
  mkdir -p "${root}/occupied-repo" "${root}/Pocketbase-CLI"
  printf 'not-a-repo\n' > "${root}/occupied-repo/README.txt"
  printf 'not-a-repo\n' > "${root}/Pocketbase-CLI/README.txt"
  mockbin="${root}/mockbin"
  create_mock_toolchain "${mockbin}" "installed-help-ok"
  sanitized_path="${mockbin}:/usr/bin:/bin"
  shared_repo="${home_dir}/.local/share/pocketbase-cli"

  output="$(
    env HOME="${home_dir}" \
      PATH="${sanitized_path}" \
      POCKETBASE_CLI_REPO="${root}/occupied-repo" \
      "${skill_copy}/scripts/run-pocketbase-cli.sh" --help 2>&1
  )"

  assert_contains "${output}" "installed-help-ok" "install fallback runtime reload"

  state_file="${skill_copy}/.runtime/repo_path"
  [[ -f "${state_file}" ]] || fail "install fallback runtime reload: missing ${state_file}"
  state_repo="$(head -n 1 "${state_file}")"
  [[ -n "${state_repo}" ]] || fail "install fallback runtime reload: empty repo_path"
  [[ "${state_repo}" == "${shared_repo}" ]] ||
    fail "install fallback runtime reload: expected shared repo path ${shared_repo}, got ${state_repo}"
  [[ -f "${state_repo}/dist/bin.js" ]] ||
    fail "install fallback runtime reload: built CLI missing at ${state_repo}/dist/bin.js"

  pass "runner reloads shared repo path after automatic install fallback"
}

test_missing_env_bin_fallback
test_incompatible_repo_candidate_rejected
test_global_path_cli_preferred
test_install_fallback_runtime_reload

printf '\nAll self-tests passed.\n'
