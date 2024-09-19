#!/bin/bash
# Version: 1.0.0
# Copyright (C) 2024 Calin Radoni
# License MIT (https://opensource.org/license/mit/)
# https://github.com/CalinRadoni/Scripts

if command -v podman >/dev/null 2>&1; then
  cm='podman'
elif command -v docker >/dev/null 2>&1; then
  cm='docker'
else
  printf 'Podman or Docker are required!\n'
  exit 1
fi

$cm run -it --rm \
  -v "${PWD}":/app:Z -w /app \
  -p 127.0.0.1:4321:4321 \
  node:lts /bin/bash -c 'npx astro telemetry disable && npm run dev'
