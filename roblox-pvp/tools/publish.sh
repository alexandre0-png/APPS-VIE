#!/usr/bin/env bash
# Prépare la publication : vérifie, applique les Id d'achats (publication/ids.json) et construit le fichier de place.
# Ne publie RIEN : l'ouverture dans Studio et « Publish to Roblox » restent manuels (compte requis).
# Prérequis : rojo (https://rojo.space). Variables : LUAU_ANALYZE, LUAU, ROBLOX_TYPES (voir tools/test.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
tools/test.sh
if [ -f publication/ids.json ]; then python3 tools/apply_ids.py; else echo "(publication/ids.json absent : achats laissés désactivés)"; fi
command -v rojo >/dev/null || { echo "rojo introuvable : installez-le puis relancez"; exit 1; }
rojo build -o ArenaDesLegendes.rbxl
echo "Fichier prêt : ArenaDesLegendes.rbxl -> ouvrez-le dans Roblox Studio, puis File > Publish to Roblox."
