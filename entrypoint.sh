#!/bin/sh
set -e

ARGS=""

if [ -n "$INPUT_DIR" ]; then
  ARGS="$ARGS --dir $INPUT_DIR"
fi

if [ -n "$INPUT_FILE" ]; then
  ARGS="$ARGS --file $INPUT_FILE"
fi

if [ "$INPUT_CI" = "true" ]; then
  ARGS="$ARGS --ci"
fi

if [ -n "$INPUT_PROJECT_ID" ]; then
  ARGS="$ARGS --project-id $INPUT_PROJECT_ID"
fi

if [ -n "$INPUT_API_KEY" ]; then
  ARGS="$ARGS --api-key $INPUT_API_KEY"
fi

echo "Running: cybedefend scan $ARGS"
cybedefend scan $ARGS
