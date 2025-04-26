#!/bin/sh
set -e

export CYBEDEFEND_API_KEY="${INPUT_API_KEY}"
export CYBEDEFEND_PROJECT_ID="${INPUT_PROJECT_ID}"

echo "Running: /app/cybedefend scan --ci --dir ."
/app/cybedefend scan --ci --dir .
