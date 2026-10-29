#!/bin/bash

cmd=$(jq -r '.tool_input.command // empty')

if CMD="$cmd" perl -e 'exit !($ENV{CMD} =~ /(?:^|[;&|(\n]\s*|\b(?:then|do|exec|xargs)\s+)(?:python3?|pip3?)(?:\s|$)/)'; then
  echo "Use uv run python or uv pip instead of bare python or pip." >&2
  exit 2
fi
