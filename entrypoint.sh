#!/bin/sh
#
# Entrypoint for the CybeDefend Docker action.
#
# Every input arrives from a workflow that may interpolate untrusted event data
# (README.md wires `branch` from `github.head_ref`, which a pull request author
# controls), so two rules apply here:
#
#   1. the CLI invocation is built as positional parameters and run with
#      `exec "$@"` — never as a command string expanded unquoted, which would
#      field-split and glob-expand every value (CWE-88 argument injection);
#   2. inputs with a domain documented in action.yml (api_url, region,
#      break_on_severity, interval, policy_timeout, report_format, report_type,
#      report_filename) are checked against that domain and fail closed with a
#      clear message.
#
# The action runs up to two commands: the scan, then — when report_format asks
# for one — a `results` export. The scan is therefore no longer exec'd: its
# exit code has to outlive the export, because a failing break_on_severity gate
# is exactly when the findings are wanted.
#
# See tests/entrypoint.bats.
set -e

fail() {
  printf 'cybedefend-action: %s\n' "$1" >&2
  exit 1
}

# api_url decides which host receives CYBEDEFEND_PAT, so it is the one value
# whose validation directly protects a credential: require an https:// URL with
# a plain host — no other scheme, no embedded credentials, no whitespace and no
# shell or glob metacharacters.
validate_api_url() {
  case "$1" in
  https://*) ;;
  *)
    fail "api_url must use the https:// scheme (got: '$1')"
    ;;
  esac

  _rest="${1#https://}"
  _host="${_rest%%/*}"
  case "$_host" in
  '' | *[!A-Za-z0-9.:-]*)
    fail "api_url must have a plain host, optionally with a port (got: '$1')"
    ;;
  esac

  _path="${_rest#"$_host"}"
  case "$_path" in
  *[!A-Za-z0-9._~/%-]*)
    fail "api_url path contains unsupported characters (got: '$1')"
    ;;
  esac
}

# validate_enum <input name> <value> <allowed>...
validate_enum() {
  _name="$1"
  _value="$2"
  shift 2
  for _allowed in "$@"; do
    if [ "$_value" = "$_allowed" ]; then
      return 0
    fi
  done
  fail "$_name must be one of: $* (got: '$_value')"
}

# validate_seconds <input name> <value>
validate_seconds() {
  case "$2" in
  '' | *[!0-9]*)
    fail "$1 must be a whole number of seconds (got: '$2')"
    ;;
  esac
}

# validate_filename <input name> <value>
#
# The report is written with --filepath pointing at the workspace, so the name
# must stay a plain file name: a separator or a '..' would place the file
# somewhere else on the runner, and a leading dash would read as a CLI flag.
validate_filename() {
  case "$2" in
  -*)
    fail "$1 must not start with '-' (got: '$2')"
    ;;
  */* | *..*)
    fail "$1 must be a plain file name, without a path (got: '$2')"
    ;;
  '' | *[!A-Za-z0-9._-]*)
    fail "$1 must only contain letters, digits, '.', '_' and '-' (got: '$2')"
    ;;
  esac
}

# report_extension <format> — the extension each consumer expects.
report_extension() {
  case "$1" in
  markdown) printf 'md' ;;
  *) printf '%s' "$1" ;;
  esac
}

# print_argv — one element per line, so a value that was field-split or
# glob-expanded shows up as extra lines.
print_argv() {
  for _arg in "$@"; do
    printf '%s\n' "${_arg}"
  done
}

if [ -n "${INPUT_REGION}" ]; then
  validate_enum region "${INPUT_REGION}" us eu
fi
if [ -n "${INPUT_API_URL}" ]; then
  validate_api_url "${INPUT_API_URL}"
fi
if [ -n "${INPUT_INTERVAL}" ]; then
  validate_seconds interval "${INPUT_INTERVAL}"
fi
if [ -n "${INPUT_BREAK_ON_SEVERITY}" ]; then
  validate_enum break_on_severity "${INPUT_BREAK_ON_SEVERITY}" \
    critical high medium low none
fi
if [ -n "${INPUT_POLICY_TIMEOUT}" ]; then
  validate_seconds policy_timeout "${INPUT_POLICY_TIMEOUT}"
fi
if [ -n "${INPUT_REPORT_FORMAT}" ]; then
  validate_enum report_format "${INPUT_REPORT_FORMAT}" \
    none sarif json html markdown
fi
if [ -n "${INPUT_REPORT_TYPE}" ]; then
  validate_enum report_type "${INPUT_REPORT_TYPE}" \
    all sast sca iac secret cicd container
fi
if [ -n "${INPUT_REPORT_FILENAME}" ]; then
  validate_filename report_filename "${INPUT_REPORT_FILENAME}"
fi

export CYBEDEFEND_PAT="${INPUT_PAT}"
export CYBEDEFEND_PROJECT_ID="${INPUT_PROJECT_ID}"

# Only export optional env vars when provided to avoid overriding pre-set values
if [ -n "${INPUT_REGION}" ]; then
  export CYBEDEFEND_REGION="${INPUT_REGION}"
fi
if [ -n "${INPUT_API_URL}" ]; then
  export CYBEDEFEND_API_URL="${INPUT_API_URL}"
fi

# The command is assembled as positional parameters: one input, one argv
# element, whatever the input contains.
set -- /app/cybedefend scan --ci --dir .

# Precedence: --api-url > env CYBEDEFEND_API_URL > --region > env CYBEDEFEND_REGION
if [ -n "${INPUT_API_URL}" ]; then
  set -- "$@" --api-url "${INPUT_API_URL}"
elif [ -n "${INPUT_REGION}" ]; then
  set -- "$@" --region "${INPUT_REGION}"
fi

if [ "${INPUT_WAIT}" = "false" ]; then
  set -- "$@" --wait=false
fi

if [ -n "${INPUT_INTERVAL}" ]; then
  set -- "$@" --interval "${INPUT_INTERVAL}"
fi

if [ "${INPUT_BREAK_ON_FAIL}" = "true" ]; then
  set -- "$@" --break-on-fail
fi

if [ -n "${INPUT_BREAK_ON_SEVERITY}" ]; then
  set -- "$@" --break-on-severity "${INPUT_BREAK_ON_SEVERITY}"
fi

if [ -n "${INPUT_BRANCH}" ]; then
  set -- "$@" --branch "${INPUT_BRANCH}"
fi

if [ "${INPUT_POLICY_CHECK}" = "false" ]; then
  set -- "$@" --policy-check=false
fi

if [ -n "${INPUT_POLICY_TIMEOUT}" ]; then
  set -- "$@" --policy-timeout "${INPUT_POLICY_TIMEOUT}"
fi

if [ "${INPUT_SHOW_POLICY_VULNS}" = "false" ]; then
  set -- "$@" --show-policy-vulns=false
fi

if [ "${INPUT_SHOW_ALL_POLICY_VULNS}" = "true" ]; then
  set -- "$@" --show-all-policy-vulns
fi

# Test hook (tests/entrypoint.bats): print the exact argv each command would
# receive, one element per line, instead of running it, and take the scan's
# exit code from CYBEDEFEND_ACTION_DRY_RUN_SCAN_EXIT so the control flow around
# a failing gate stays testable. Never set in normal action usage.
if [ -n "${CYBEDEFEND_ACTION_DRY_RUN}" ]; then
  print_argv "$@"
  scan_exit="${CYBEDEFEND_ACTION_DRY_RUN_SCAN_EXIT:-0}"
else
  set +e
  "$@"
  scan_exit=$?
  set -e
fi

report_format="${INPUT_REPORT_FORMAT:-none}"

if [ "${report_format}" != none ]; then
  report_type="${INPUT_REPORT_TYPE:-all}"
  report_filename="${INPUT_REPORT_FILENAME:-cybedefend-results.$(report_extension "${report_format}")}"
  # In a Docker action the workspace is mounted at $GITHUB_WORKSPACE; the report
  # has to land there to be visible to the steps that follow.
  report_dir="${GITHUB_WORKSPACE:-.}"

  # Same argv discipline as the scan: one input, one element.
  set -- /app/cybedefend results --ci

  # The export must reach the host the scan reached: the CLI's --api-url
  # defaults to the US region, so an EU scan would otherwise report from the
  # wrong place.
  if [ -n "${INPUT_API_URL}" ]; then
    set -- "$@" --api-url "${INPUT_API_URL}"
  elif [ -n "${INPUT_REGION}" ]; then
    set -- "$@" --region "${INPUT_REGION}"
  fi

  set -- "$@" --project-id "${INPUT_PROJECT_ID}"

  # --branch defaults to every branch in the CLI, so leaving it out would
  # export results the scan never produced.
  if [ -n "${INPUT_BRANCH}" ]; then
    set -- "$@" --branch "${INPUT_BRANCH}"
  fi

  set -- "$@" \
    --type "${report_type}" \
    --output "${report_format}" \
    --filepath "${report_dir}" \
    --filename "${report_filename}"

  # A failed export must not turn a passing scan into a failing job.
  if [ -n "${CYBEDEFEND_ACTION_DRY_RUN}" ]; then
    printf '=== results ===\n'
    print_argv "$@"
    export_ok=yes
  elif "$@"; then
    export_ok=yes
  else
    export_ok=no
    printf '::warning::CybeDefend report export failed; the scan result is unaffected\n'
  fi

  if [ "${export_ok}" = yes ]; then
    # A Docker action runs as root, so the report lands in the workspace owned
    # by root: make it readable by whatever post-processes it later.
    if [ -f "${report_dir}/${report_filename}" ]; then
      chmod a+r "${report_dir}/${report_filename}"
    fi

    # Relative on purpose: the steps that consume this run on the runner, where
    # the container's workspace path does not exist.
    if [ -n "${GITHUB_OUTPUT}" ]; then
      printf 'report_file=%s\n' "${report_filename}" >>"${GITHUB_OUTPUT}"
      printf 'report_format=%s\n' "${report_format}" >>"${GITHUB_OUTPUT}"
    fi
  fi
fi

exit "${scan_exit}"
