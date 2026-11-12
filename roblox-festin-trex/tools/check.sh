#!/usr/bin/env bash
# Vérification statique : luau-lsp (types Roblox réels) sur tout src/.
# Usage : TOOLS=/chemin/vers/dossier ./tools/check.sh
# TOOLS doit contenir luau-lsp et globalTypes.d.luau (voir README).
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="${TOOLS:?définir TOOLS}"
"$TOOLS/luau-lsp" analyze --definitions="$TOOLS/globalTypes.d.luau" --no-flags-enabled \
  --sourcemap=sourcemap.json --ignore='**/globalTypes*' src
