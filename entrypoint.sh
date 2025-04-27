#!/bin/sh
set -e

export CYBEDEFEND_API_KEY="${INPUT_API_KEY}"
export CYBEDEFEND_PROJECT_ID="${INPUT_PROJECT_ID}"

CMD="/app/cybedefend scan --ci --dir ."

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
