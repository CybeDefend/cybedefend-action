#!/bin/sh
set -e

export CYBEDEFEND_API_KEY="${INPUT_API_KEY}"
export CYBEDEFEND_PROJECT_ID="${INPUT_PROJECT_ID}"

/app/cybedefend scan --ci --dir .
