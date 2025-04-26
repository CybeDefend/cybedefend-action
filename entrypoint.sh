#!/bin/sh
set -e

# Export secrets safely as environment variables (if provided)
if [ -n "$INPUT_API_KEY" ]; then
  export CYBEDEFEND_API_KEY="$INPUT_API_KEY"
fi

if [ -n "$INPUT_PROJECT_ID" ]; then
  export CYBEDEFEND_PROJECT_ID="$INPUT_PROJECT_ID"
fi

# Run CLI (it reads from env vars safely)
cybedefend scan --ci --dir .
