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

  mkdir -p "${bin_dir}"

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
  ci|install)
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

test_missing_env_bin_fallback() {
  local root skill_copy output

  root="${tmp_root}/test-missing-bin"
  skill_copy="$(setup_skill_copy "${root}")"
  create_compatible_repo "${root}/Pocketbase-CLI" "default-help-ok"

  output="$(
    env POCKETBASE_CLI_BIN=/definitely/missing \
      "${skill_copy}/scripts/run-pocketbase-cli.sh" --help 2>&1
  )"

  assert_contains "${output}" "Ignoring missing POCKETBASE_CLI_BIN" "missing env fallback"
  assert_contains "${output}" "default-help-ok" "missing env fallback"
  pass "missing POCKETBASE_CLI_BIN falls through to a compatible repo"
}

test_incompatible_repo_candidate_rejected() {
  local root skill_copy output

  root="${tmp_root}/test-incompatible-repo"
  skill_copy="$(setup_skill_copy "${root}")"
  create_compatible_repo "${root}/Pocketbase-CLI" "default-help-ok"
  create_incompatible_repo "${root}/occupied-repo"

  output="$(
    env POCKETBASE_CLI_REPO="${root}/occupied-repo" \
      "${skill_copy}/scripts/run-pocketbase-cli.sh" --help 2>&1
  )"

  assert_contains "${output}" "Ignoring incompatible repo candidate" "incompatible repo rejection"
  assert_not_contains "${output}" "FAKE-CLI-RAN" "incompatible repo rejection"
  assert_contains "${output}" "default-help-ok" "incompatible repo rejection"
  pass "runner rejects incompatible repo candidates before fallback"
}

test_install_fallback_runtime_reload() {
  local root skill_copy mockbin output state_file state_repo expected_runtime_dir

  root="${tmp_root}/test-install-fallback"
  skill_copy="$(setup_skill_copy "${root}")"
  mkdir -p "${root}/occupied-repo" "${root}/Pocketbase-CLI"
  printf 'not-a-repo\n' > "${root}/occupied-repo/README.txt"
  printf 'not-a-repo\n' > "${root}/Pocketbase-CLI/README.txt"
  mockbin="${root}/mockbin"
  create_mock_toolchain "${mockbin}" "installed-help-ok"

  output="$(
    env PATH="${mockbin}:${PATH}" \
      POCKETBASE_CLI_REPO="${root}/occupied-repo" \
      "${skill_copy}/scripts/run-pocketbase-cli.sh" --help 2>&1
  )"

  assert_contains "${output}" "installed-help-ok" "install fallback runtime reload"

  state_file="${skill_copy}/.runtime/repo_path"
  [[ -f "${state_file}" ]] || fail "install fallback runtime reload: missing ${state_file}"
  state_repo="$(head -n 1 "${state_file}")"
  [[ -n "${state_repo}" ]] || fail "install fallback runtime reload: empty repo_path"
  expected_runtime_dir="$(cd "${skill_copy}/.runtime" && pwd)"
  [[ "${state_repo}" == "${expected_runtime_dir}/Pocketbase-CLI."* ]] ||
    fail "install fallback runtime reload: expected runtime repo path, got ${state_repo}"
  [[ -f "${state_repo}/dist/bin.js" ]] ||
    fail "install fallback runtime reload: built CLI missing at ${state_repo}/dist/bin.js"

  pass "runner reloads .runtime repo_path after automatic install fallback"
}

test_missing_env_bin_fallback
test_incompatible_repo_candidate_rejected
test_install_fallback_runtime_reload

printf '\nAll self-tests passed.\n'
