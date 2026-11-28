#!/usr/bin/env bash
# Usage: scripts/check-game.sh <dossier-du-jeu>
# Lance les contrôles disponibles et signale les outils absents. Code de sortie non nul si un contrôle échoue.
set -u
GAME="${1:?dossier du jeu requis}"
export PATH="$HOME/.roblox-tools/bin:$HOME/.cargo/bin:$PATH"
fail=0
run() { local name="$1"; shift
  if ! command -v "$1" >/dev/null 2>&1; then echo "[ABSENT ] $name ($1 introuvable)"; return; fi
  if "$@"; then echo "[OK     ] $name"; else echo "[ECHEC  ] $name"; fail=1; fi; }
cd "$GAME" || exit 2
run "stylua --check"  stylua --check src
if command -v selene >/dev/null 2>&1; then
  out=$(selene src 2>&1); rc=$?
  if [ $rc -eq 0 ]; then echo "[OK     ] selene"
  elif echo "$out" | grep -q "API dump"; then echo "[LIMITE ] selene : std roblox indisponible (API dump non téléchargeable, réseau restreint)"
  else echo "$out"; echo "[ECHEC  ] selene"; fail=1; fi
else echo "[ABSENT ] selene"; fi
if [ -f default.project.json ]; then run "rojo build" rojo build -o /tmp/check-game.rbxl default.project.json; fi
if [ -d tests ]; then
  for t in tests/*.luau tests/*.lua; do [ -e "$t" ] && run "lune $t" lune run "$t"; done
fi
exit $fail
