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
#      break_on_severity, interval, policy_timeout) are checked against that
#      domain and fail closed with a clear message.
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

# Test hook (tests/entrypoint.bats): print the exact argv the CLI would receive,
# one element per line, instead of running it. Never set in normal action usage.
if [ -n "${CYBEDEFEND_ACTION_DRY_RUN}" ]; then
  for arg in "$@"; do
    printf '%s\n' "${arg}"
  done
  exit 0
fi

exec "$@"
