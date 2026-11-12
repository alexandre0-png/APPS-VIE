#!/usr/bin/env bash
# Lance les tests unitaires avec le CLI Luau (https://github.com/luau-lang/luau/releases).
# Usage : LUAU=/chemin/vers/luau ./tests/run.sh   (par défaut : "luau" dans le PATH)
set -euo pipefail
cd "$(dirname "$0")/.."
LUAU="${LUAU:-luau}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for f in src/shared/*.luau src/server/Services/DataService.luau; do
  sed -E 's#require\(script\.Parent\.([A-Za-z]+)\)#require("./\1")#; s#require\(Shared:WaitForChild\("([A-Za-z]+)"\)\)#require("./\1")#' "$f" > "$tmp/$(basename "$f")"
done
cp tests/test_all.luau "$tmp/"
cd "$tmp"
"$LUAU" test_all.luau
