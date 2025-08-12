#!/bin/sh
set -e

export CYBEDEFEND_API_KEY="${INPUT_API_KEY}"
export CYBEDEFEND_PROJECT_ID="${INPUT_PROJECT_ID}"

# Only export optional env vars when provided to avoid overriding pre-set values
if [ -n "${INPUT_REGION}" ]; then
  export CYBEDEFEND_REGION="${INPUT_REGION}"
fi
if [ -n "${INPUT_API_URL}" ]; then
  export CYBEDEFEND_API_URL="${INPUT_API_URL}"
fi

CMD="/app/cybedefend scan --ci --dir ."

# Precedence: --api-url > env CYBEDEFEND_API_URL > --region > env CYBEDEFEND_REGION
if [ -n "${INPUT_API_URL}" ]; then
  CMD="${CMD} --api-url ${INPUT_API_URL}"
elif [ -n "${INPUT_REGION}" ]; then
  CMD="${CMD} --region ${INPUT_REGION}"
fi

if [ "${INPUT_WAIT}" = "false" ]; then
  CMD="${CMD} --wait=false"
fi

if [ -n "${INPUT_INTERVAL}" ]; then
  CMD="${CMD} --interval ${INPUT_INTERVAL}"
fi

if [ "${INPUT_BREAK_ON_FAIL}" = "true" ]; then
  CMD="${CMD} --break-on-fail"
fi

if [ -n "${INPUT_BREAK_ON_SEVERITY}" ]; then
  CMD="${CMD} --break-on-severity ${INPUT_BREAK_ON_SEVERITY}"
fi

exec ${CMD}
