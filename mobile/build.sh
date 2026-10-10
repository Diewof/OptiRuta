#!/usr/bin/env bash
# Wrapper para no tener que escribir --dart-define-from-file=.env cada vez.
# Uso: ./build.sh              -> flutter build apk --release
#      ./build.sh appbundle    -> flutter build appbundle --release
#      ./build.sh apk --debug  -> cualquier argumento extra se reenvia tal cual
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "No existe mobile/.env. Copia .env.example a .env y completa los valores." >&2
  exit 1
fi

TARGET="${1:-apk}"
if [ "$#" -gt 0 ]; then shift; fi

flutter build "$TARGET" "--dart-define-from-file=$ENV_FILE" --release "$@"
