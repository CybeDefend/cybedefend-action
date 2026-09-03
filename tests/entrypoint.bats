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

  # The runner's $GITHUB_OUTPUT, where step outputs are appended.
  GITHUB_OUTPUT_FILE="$WORKDIR/github_output"
  : >"$GITHUB_OUTPUT_FILE"

  # Separates the two commands in dry-run output: everything after it is the
  # argv of the `results` export, which only runs when a report is requested.
  RESULTS_MARKER='=== results ==='
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
    GITHUB_WORKSPACE="$WORKDIR" \
    GITHUB_OUTPUT="$GITHUB_OUTPUT_FILE" \
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

# assert_step_output line — $GITHUB_OUTPUT must contain exactly this line.
assert_step_output() {
  if ! grep -qxF -- "$1" "$GITHUB_OUTPUT_FILE"; then
    printf 'expected step output %s\nGITHUB_OUTPUT contains:\n%s\n' \
      "$1" "$(cat "$GITHUB_OUTPUT_FILE")" >&2
    false
  fi
}

# assert_no_step_output — nothing was written to $GITHUB_OUTPUT.
assert_no_step_output() {
  if [ -s "$GITHUB_OUTPUT_FILE" ]; then
    printf 'expected no step output, got:\n%s\n' "$(cat "$GITHUB_OUTPUT_FILE")" >&2
    false
  fi
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

# --- results export ---------------------------------------------------------
#
# `report_format` defaults to none, so the export is opt-in and every test
# above still describes the whole behaviour of the action when it is unset.
#
# The export runs as a second command, after the scan. In dry-run its argv is
# printed after RESULTS_MARKER.

@test "no report is exported unless report_format asks for one" {
  run_entrypoint INPUT_BRANCH=main
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --branch main
  assert_no_step_output
}

@test "report_format none is the documented way to keep the old behaviour" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=none
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --branch main
  assert_no_step_output
}

@test "report_format sarif exports a report after the scan" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --branch main \
    "$RESULTS_MARKER" \
    /app/cybedefend results --ci \
    --project-id 11111111-2222-3333-4444-555555555555 \
    --branch main \
    --type all \
    --output sarif \
    --filepath "$WORKDIR" \
    --filename cybedefend-results.sarif
}

@test "the report covers the scanned branch only" {
  # --branch defaults to *every* branch in the CLI, so omitting it would export
  # results the scan never produced.
  run_entrypoint INPUT_BRANCH=feature/my-feature INPUT_REPORT_FORMAT=sarif
  assert_ok
  case "$output" in
  *"$RESULTS_MARKER"*--branch$'\n'feature/my-feature*) ;;
  *)
    printf 'the results command must scope to the scanned branch\noutput:\n%s\n' "$output" >&2
    false
    ;;
  esac
}

@test "each format gets the file extension its consumer expects" {
  for format_and_name in \
    sarif:cybedefend-results.sarif \
    json:cybedefend-results.json \
    html:cybedefend-results.html \
    markdown:cybedefend-results.md; do
    format="${format_and_name%%:*}"
    name="${format_and_name#*:}"

    run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT="$format"
    assert_ok
    case "$output" in
    *"--filename"$'\n'"$name"*) ;;
    *)
      printf 'format %s must default to %s\noutput:\n%s\n' "$format" "$name" "$output" >&2
      false
      ;;
    esac
  done
}

@test "report_filename overrides the default name" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif \
    INPUT_REPORT_FILENAME=findings.sarif
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --branch main \
    "$RESULTS_MARKER" \
    /app/cybedefend results --ci \
    --project-id 11111111-2222-3333-4444-555555555555 \
    --branch main \
    --type all \
    --output sarif \
    --filepath "$WORKDIR" \
    --filename findings.sarif
}

@test "report_type narrows the report to one scan type" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=json INPUT_REPORT_TYPE=sast
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --branch main \
    "$RESULTS_MARKER" \
    /app/cybedefend results --ci \
    --project-id 11111111-2222-3333-4444-555555555555 \
    --branch main \
    --type sast \
    --output json \
    --filepath "$WORKDIR" \
    --filename cybedefend-results.json
}

@test "the export reaches the same host as the scan" {
  # CYBEDEFEND_API_URL competes with the CLI's --api-url default (US), so the
  # flag has to be forwarded or the report is fetched from the wrong region.
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif \
    INPUT_API_URL=https://api-eu.cybedefend.com
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . \
    --api-url https://api-eu.cybedefend.com --branch main \
    "$RESULTS_MARKER" \
    /app/cybedefend results --ci \
    --api-url https://api-eu.cybedefend.com \
    --project-id 11111111-2222-3333-4444-555555555555 \
    --branch main \
    --type all \
    --output sarif \
    --filepath "$WORKDIR" \
    --filename cybedefend-results.sarif
}

@test "the export follows region when api_url is absent" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif INPUT_REGION=eu
  assert_ok
  assert_argv /app/cybedefend scan --ci --dir . --region eu --branch main \
    "$RESULTS_MARKER" \
    /app/cybedefend results --ci \
    --region eu \
    --project-id 11111111-2222-3333-4444-555555555555 \
    --branch main \
    --type all \
    --output sarif \
    --filepath "$WORKDIR" \
    --filename cybedefend-results.sarif
}

@test "the generated report is exposed as a step output" {
  # The path is relative: upload-sarif runs on the runner, where the container's
  # /github/workspace does not exist.
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif
  assert_ok
  assert_step_output "report_file=cybedefend-results.sarif"
  assert_step_output "report_format=sarif"
}

# --- the export must not change whether the job passes ----------------------

@test "a failing scan gate still exports the report and still fails the step" {
  # This is the case that matters: a break_on_severity failure is exactly when
  # the findings are wanted.
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif \
    CYBEDEFEND_ACTION_DRY_RUN_SCAN_EXIT=1
  if [ "$status" -ne 1 ]; then
    printf 'expected the scan exit code to survive the export, got %s\n' "$status" >&2
    false
  fi
  case "$output" in
  *"$RESULTS_MARKER"*) ;;
  *)
    printf 'the report must be exported even when the scan gate fails\noutput:\n%s\n' "$output" >&2
    false
    ;;
  esac
}

@test "the scan exit code survives an export that was not requested" {
  run_entrypoint INPUT_BRANCH=main CYBEDEFEND_ACTION_DRY_RUN_SCAN_EXIT=2
  if [ "$status" -ne 2 ]; then
    printf 'expected status 2, got %s\n' "$status" >&2
    false
  fi
}

# --- report inputs are validated like every other documented domain ---------

@test "report_format is checked against the documented enum" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=pdf
  assert_rejected report_format
}

@test "report_format cannot smuggle a second argument" {
  run_entrypoint INPUT_BRANCH=main \
    INPUT_REPORT_FORMAT='sarif --api-url https://evil.tld'
  assert_rejected report_format
}

@test "report_type is checked against the documented enum" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif INPUT_REPORT_TYPE=everything
  assert_rejected report_type
}

@test "report_filename cannot escape the workspace" {
  # --filepath is the workspace; a traversal in --filename would write outside it.
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif \
    INPUT_REPORT_FILENAME=../../etc/cron.d/payload
  assert_rejected report_filename
}

@test "report_filename cannot contain a path separator" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif \
    INPUT_REPORT_FILENAME=nested/findings.sarif
  assert_rejected report_filename
}

@test "report_filename cannot start with a dash" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif \
    INPUT_REPORT_FILENAME=--api-url=https://evil.tld
  assert_rejected report_filename
}

@test "report_filename cannot smuggle a second argument" {
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=sarif \
    INPUT_REPORT_FILENAME='findings.sarif --api-url https://evil.tld'
  assert_rejected report_filename
}

@test "a rejected report input never starts the scan" {
  # Validation runs before the scan, so a typo does not burn a scan credit.
  run_entrypoint INPUT_BRANCH=main INPUT_REPORT_FORMAT=pdf
  assert_rejected report_format
  assert_no_step_output
}
