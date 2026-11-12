#!/usr/bin/env bash
# Chaîne de vérification complète :
#   1. analyse statique Luau (syntaxe, variables, requires, types inter-modules)
#   2. contrôles sémantiques (membres de modules, Remotes, attributs)
#   3. noms d'API Roblox (classes, propriétés, enums, méthodes) vs définitions officielles
#   4. tests unitaires (logique pure) et simulation serveur (faux environnement Roblox)
# Prérequis : `luau` et `luau-analyze` (https://github.com/luau-lang/luau/releases)
#             et globalTypes.d.luau (https://github.com/JohnnyMorganz/luau-lsp/tree/main/scripts)
set -euo pipefail
cd "$(dirname "$0")/.."
ANALYZE="${LUAU_ANALYZE:-luau-analyze}"
LUAU="${LUAU:-luau}"
python3 tools/check.py --analyze "$ANALYZE"
if [ -n "${ROBLOX_TYPES:-}" ]; then python3 tools/check_api.py "$ROBLOX_TYPES"; else echo "(ROBLOX_TYPES non défini : contrôle d'API ignoré)"; fi
rm -rf .emit
INJECT_MOCK=1 python3 tools/check.py --analyze "$ANALYZE" --emit .emit > /dev/null || true
"$LUAU" tests/run.luau
"$LUAU" tests/sim.luau
rm -rf .emit
echo "TOUT EST VERT"
