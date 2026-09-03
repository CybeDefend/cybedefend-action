#!/usr/bin/env bats
#
# Tests for entrypoint.sh — they assert the exact argv handed to the CybeDefend
# CLI, and that inputs with a documented domain are rejected before the CLI is
# ever reached.
#
# The entrypoint is run with CYBEDEFEND_ACTION_DRY_RUN=1, which makes it print
# the argv it would exec, one element per line, instead of running the CLI.
# One line of output == one argv element, so a value that gets field-split or
# glob-expanded shows up as extra lines.
#
# Run from the repository root:  bats tests/

setup() {
  ENTRYPOINT="${ENTRYPOINT:-$BATS_TEST_DIRNAME/../entrypoint.sh}"
  # Override to exercise another POSIX shell, e.g. SH=/bin/dash bats tests/
  SH="${SH:-/bin/sh}"

  # Stand in for the checked-out third-party repository the action scans:
  # attacker-chosen filenames live here, so an unquoted expansion would turn
  # them into argv elements.
  WORKDIR="$(mktemp -d)"
  : >"$WORKDIR/README.md"
  : >"$WORKDIR/main.tf"
}

teardown() {
  [ -n "$WORKDIR" ] && rm -rf "$WORKDIR"
}

# run_entrypoint VAR=value... — runs the entrypoint in a pristine environment
# (only the variables listed here exist) with the scanned repo as cwd.
run_entrypoint() {
  cd "$WORKDIR" || return 1
  run env -i \
    PATH="$PATH" \
    CYBEDEFEND_ACTION_DRY_RUN=1 \
    INPUT_PAT=pat-secret \
    INPUT_PROJECT_ID=11111111-2222-3333-4444-555555555555 \
    "$@" \
    "$SH" "$ENTRYPOINT"
}

assert_ok() {
  if [ "$status" -ne 0 ]; then
    printf 'expected success, got status %s\noutput:\n%s\n' "$status" "$output" >&2
    false
  fi
}

# assert_argv element... — the printed argv must match exactly, element for
# element. Anything extra means a value was split or expanded.
assert_argv() {
  local expected
  expected="$(printf '%s\n' "$@")"
  if [ "$output" != "$expected" ]; then
    printf 'expected argv:\n%s\n----------\nactual argv:\n%s\n' "$expected" "$output" >&2
    false
  fi
}

# assert_rejected fragment — the entrypoint must fail without printing argv.
assert_rejected() {
  if [ "$status" -eq 0 ]; then
    printf 'expected a non-zero exit, got 0\noutput:\n%s\n' "$output" >&2
    false
  fi
  case "$output" in
  *"$1"*) ;;
  *)
    printf 'expected the error to mention %s\noutput:\n%s\n' "$1" "$output" >&2
    false
    ;;
  esac
  case "$output" in
  *"/app/cybedefend"*)
    printf 'a rejected input must not reach the CLI\noutput:\n%s\n' "$output" >&2
    false
    ;;
  esac
}

# --- baseline behaviour -----------------------------------------------------

@test "defaults produce the documented scan command" {
  run_entrypoint INPUT_BRANCH=main
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --branch main
}

@test "every option is forwarded, in the documented order" {
  run_entrypoint \
    INPUT_API_URL=https://api-eu.cybedefend.com \
    INPUT_WAIT=false \
    INPUT_INTERVAL=10 \
    INPUT_BREAK_ON_FAIL=true \
    INPUT_BREAK_ON_SEVERITY=high \
    INPUT_BRANCH=feature/my-feature \
    INPUT_POLICY_CHECK=false \
    INPUT_POLICY_TIMEOUT=600 \
    INPUT_SHOW_POLICY_VULNS=false \
    INPUT_SHOW_ALL_POLICY_VULNS=true
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . \
    --api-url https://api-eu.cybedefend.com \
    --wait=false \
    --interval 10 \
    --break-on-fail \
    --break-on-severity high \
    --branch feature/my-feature \
    --policy-check=false \
    --policy-timeout 600 \
    --show-policy-vulns=false \
    --show-all-policy-vulns
}

@test "api_url takes precedence over region" {
  run_entrypoint \
    INPUT_BRANCH=main \
    INPUT_REGION=eu \
    INPUT_API_URL=https://api-eu.cybedefend.com
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . \
    --api-url https://api-eu.cybedefend.com --branch main
}

@test "region is used when api_url is absent" {
  run_entrypoint INPUT_BRANCH=main INPUT_REGION=eu
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --region eu --branch main
}

@test "boolean inputs only act on their documented value" {
  run_entrypoint \
    INPUT_BRANCH=main \
    INPUT_WAIT=maybe \
    INPUT_BREAK_ON_FAIL=yes \
    INPUT_POLICY_CHECK=0 \
    INPUT_SHOW_POLICY_VULNS=nope \
    INPUT_SHOW_ALL_POLICY_VULNS=1
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --branch main
}

# --- argument injection (CWE-88) --------------------------------------------

@test "a branch containing spaces stays a single argv element" {
  # Field splitting here would let the trailing --api-url win in the CLI's flag
  # parser and ship CYBEDEFEND_PAT to an attacker-controlled host.
  run_entrypoint INPUT_BRANCH='main --api-url https://evil.tld'
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . \
    --branch 'main --api-url https://evil.tld'
}

@test "a glob in an input is not expanded against the scanned repository" {
  run_entrypoint INPUT_BRANCH='*'
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --branch '*'
}

@test "a branch starting with a dash stays a single argv element" {
  run_entrypoint INPUT_BRANCH='--api-url=https://evil.tld'
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . \
    --branch '--api-url=https://evil.tld'
}

@test "a tab in a branch does not create a new argv element" {
  run_entrypoint "$(printf 'INPUT_BRANCH=main\t--wait=false')"
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . \
    --branch "$(printf 'main\t--wait=false')"
}

# --- api_url: the value that decides who receives the PAT -------------------

@test "api_url must use https" {
  run_entrypoint INPUT_BRANCH=main INPUT_API_URL=http://api-us.cybedefend.com
  assert_rejected api_url
}

@test "api_url with embedded credentials is rejected" {
  run_entrypoint INPUT_BRANCH=main \
    INPUT_API_URL=https://api-us.cybedefend.com@evil.tld
  assert_rejected api_url
}

@test "api_url containing a space is rejected" {
  run_entrypoint INPUT_BRANCH=main \
    INPUT_API_URL='https://api-us.cybedefend.com --pat leak'
  assert_rejected api_url
}

@test "api_url containing shell metacharacters is rejected" {
  run_entrypoint INPUT_BRANCH=main INPUT_API_URL='https://api-us.$(id).tld'
  assert_rejected api_url
}

@test "api_url without a host is rejected" {
  run_entrypoint INPUT_BRANCH=main INPUT_API_URL=https:///scan
  assert_rejected api_url
}

@test "a plain https api_url with a port and a path is accepted" {
  run_entrypoint INPUT_BRANCH=main \
    INPUT_API_URL=https://cybedefend.internal:8443/api/v1
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . \
    --api-url https://cybedefend.internal:8443/api/v1 --branch main
}

# --- enums and numerics documented in action.yml ----------------------------

@test "break_on_severity is checked against the documented enum" {
  run_entrypoint INPUT_BRANCH=main INPUT_BREAK_ON_SEVERITY='high --api-url https://evil.tld'
  assert_rejected break_on_severity
}

@test "break_on_severity rejects an undocumented severity" {
  run_entrypoint INPUT_BRANCH=main INPUT_BREAK_ON_SEVERITY=informational
  assert_rejected break_on_severity
}

@test "break_on_severity accepts every documented value" {
  for severity in critical high medium low none; do
    run_entrypoint INPUT_BRANCH=main "INPUT_BREAK_ON_SEVERITY=$severity"
    assert_ok
    assert_argv /app/cybedefend scan --ci --dir . \
      --break-on-severity "$severity" --branch main
  done
}

@test "interval must be numeric" {
  run_entrypoint INPUT_BRANCH=main INPUT_INTERVAL='5 --break-on-fail'
  assert_rejected interval
}

@test "policy_timeout must be numeric" {
  run_entrypoint INPUT_BRANCH=main INPUT_POLICY_TIMEOUT='300 --policy-check=false'
  assert_rejected policy_timeout
}

@test "region is checked against the documented enum" {
  run_entrypoint INPUT_BRANCH=main INPUT_REGION='eu --api-url https://evil.tld'
  assert_rejected region
}

@test "region rejects an undocumented value" {
  run_entrypoint INPUT_BRANCH=main INPUT_REGION=apac
  assert_rejected region
}
