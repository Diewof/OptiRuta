#!/usr/bin/env bash
# Wrapper para no tener que escribir --dart-define-from-file=.env cada vez.
# Uso: ./run.sh  (acepta los mismos argumentos que "flutter run", ej. ./run.sh -d chrome)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No existe mobile/.env. Copia .env.example a .env y completa los valores." >&2
  exit 1
fi

flutter run "--dart-define-from-file=$ENV_FILE" "$@"
