#!/usr/bin/env bash
# Usage : scripts/verifier_publier_chipe.sh <commit> [--publier]
#
# Automatise la procédure de vérification puis de publication (versions Published) du Jeu 2 Chipe-Œufs,
# telle qu'elle était suivie à la main (voir obsidian-studio/Studio/Procedure-publication.md).
#
# Étapes, dans l'ordre ; le script s'arrête au premier échec (code de sortie non nul) :
#   1. export du dossier roblox/ du commit dans un dossier de travail (git archive)
#   2. Lune : lune run roblox/tests/run.luau (en arrière-plan), exige « Tests Config : … 0 échoués »
#   3. python3 roblox/tools/check.py, exige « Aucun problème détecté »
#   4. python3 roblox/tools/run_tests.py, exige « code de sortie : 0 »
#   5. rojo build game.project.json et hub.project.json
#   6. publication UNIQUEMENT avec --publier : POST …/versions?versionType=Published sur la partie
#      (lieu 87012762353093) puis sur le hub (lieu 115261336085924), HTTP 200 exigé pour chacun
#   7. résumé
#
# Sans --publier, rien n'est publié. La clé API est injectée par le proxy : elle n'apparaît
# ni dans ce script ni dans les logs.
set -uo pipefail

UNIVERS=10776613087
LIEU_PARTIE=87012762353093
LIEU_HUB=115261336085924
TOOLS=/tmp/claude-0/cargo-out/bin
SCRATCH="${SCRATCH:-/tmp/claude-0/-home-user-APPS-VIE/c9e841d1-d554-571c-a61d-bf92920d8724/scratchpad}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() { echo "Usage : $0 <commit> [--publier]" >&2; exit 2; }
[ $# -ge 1 ] && [ $# -le 2 ] || usage
COMMIT="$1"
MODE_PUBLIER=0
if [ $# -eq 2 ]; then
  [ "$2" = "--publier" ] || usage
  MODE_PUBLIER=1
fi

RESUME=()
etape() { echo; echo "== [$1] $2"; }
ok() { echo "   OK : $1"; RESUME+=("$1"); }
echec() { echo "ÉCHEC : $1" >&2; echo "Résultat : échec à l'étape « $1 »." >&2; exit 1; }

# Étape 1 : export du commit
etape 1 "export du dossier roblox/ du commit"
SHA="$(git -C "$REPO" rev-parse --verify --quiet "${COMMIT}^{commit}")" || echec "commit « $COMMIT » introuvable"
DIR="$SCRATCH/verif-$COMMIT"
rm -rf "$DIR"
mkdir -p "$DIR" || echec "création de $DIR"
git -C "$REPO" archive "$SHA" roblox | tar -x -C "$DIR" || echec "git archive"
[ -f "$DIR/roblox/tests/run.luau" ] || echec "roblox/ absent du commit"
OUT="$DIR/sorties"
mkdir -p "$OUT"
echo "   commit $SHA -> $DIR"
ok "export $SHA"

# Étape 2 : Lune, tests de configuration
etape 2 "lune run roblox/tests/run.luau (arrière-plan)"
LOG_LUNE="$OUT/lune.log"
(
  cd "$DIR" && PATH="$TOOLS:$PATH" exec setsid nohup lune run roblox/tests/run.luau
) >"$LOG_LUNE" 2>&1 </dev/null &
PID_LUNE=$!
DEADLINE=$(( $(date +%s) + 900 ))
while :; do
  if grep -q "^Tests Config" "$LOG_LUNE" 2>/dev/null; then break; fi
  if ! kill -0 "$PID_LUNE" 2>/dev/null; then break; fi
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    kill "$PID_LUNE" 2>/dev/null
    echec "lune : délai de 900 s dépassé"
  fi
  sleep 5
done
wait "$PID_LUNE" 2>/dev/null
LIGNE_LUNE="$(grep -E "^Tests Config" "$LOG_LUNE" | tail -1)"
[ -n "$LIGNE_LUNE" ] || echec "lune : ligne « Tests Config » absente (voir $LOG_LUNE)"
echo "   $LIGNE_LUNE"
echo "$LIGNE_LUNE" | grep -qE "0 échoués" || echec "lune : tests échoués"
ok "Lune : $LIGNE_LUNE"

# Étape 3 : check.py
etape 3 "python3 roblox/tools/check.py"
LOG_CHECK="$OUT/check.log"
( cd "$DIR" && PATH="$TOOLS:$PATH" python3 roblox/tools/check.py ) >"$LOG_CHECK" 2>&1
RC_CHECK=$?
tail -3 "$LOG_CHECK"
[ "$RC_CHECK" -eq 0 ] || echec "check.py : code de sortie $RC_CHECK"
grep -q "Aucun problème détecté" "$LOG_CHECK" || echec "check.py : « Aucun problème détecté » absent"
ok "check.py : Aucun problème détecté"

# Étape 4 : run_tests.py
etape 4 "python3 roblox/tools/run_tests.py"
LOG_RT="$OUT/run_tests.log"
( cd "$DIR" && PATH="$TOOLS:$PATH" python3 roblox/tools/run_tests.py ) >"$LOG_RT" 2>&1
RC_RT=$?
tail -3 "$LOG_RT"
[ "$RC_RT" -eq 0 ] || echec "run_tests.py : code de sortie $RC_RT"
grep -q "code de sortie : 0" "$LOG_RT" || echec "run_tests.py : « code de sortie : 0 » absent"
ok "run_tests.py : code de sortie 0"

# Étape 5 : builds Rojo
etape 5 "rojo build (partie et hub)"
BUILD_G="$OUT/build-g.rbxl"
BUILD_H="$OUT/build-h.rbxl"
( cd "$DIR/roblox" && PATH="$TOOLS:$PATH" rojo build game.project.json -o "$BUILD_G" ) || echec "rojo build game.project.json"
( cd "$DIR/roblox" && PATH="$TOOLS:$PATH" rojo build hub.project.json -o "$BUILD_H" ) || echec "rojo build hub.project.json"
[ -s "$BUILD_G" ] && [ -s "$BUILD_H" ] || echec "builds Rojo vides ou absents"
ok "builds Rojo : partie et hub"

# Étape 6 : publication (seulement avec --publier)
VERSIONS=()
if [ "$MODE_PUBLIER" -eq 1 ]; then
  etape 6 "publication des versions Published"
  publier() { # $1 = lieu, $2 = fichier .rbxl, $3 = libellé
    local lieu="$1" fichier="$2" libelle="$3" corps="$OUT/reponse-$1.json" code num
    code="$(curl -sS -o "$corps" -w '%{http_code}' -X POST \
      "https://apis.roblox.com/universes/v1/$UNIVERS/places/$lieu/versions?versionType=Published" \
      -H "Content-Type: application/octet-stream" --data-binary "@$fichier")" || echec "publication $libelle : curl"
    echo "   $libelle (lieu $lieu) : HTTP $code"
    [ "$code" = "200" ] || echec "publication $libelle : HTTP $code (voir $corps)"
    num="$(grep -o '"versionNumber"[^,}]*' "$corps" | head -1 | grep -o '[0-9]*$')"
    VERSIONS+=("$libelle v${num:-?}")
    ok "publié $libelle : version ${num:-?}"
  }
  publier "$LIEU_PARTIE" "$BUILD_G" "partie"
  publier "$LIEU_HUB" "$BUILD_H" "hub"
else
  etape 6 "publication ignorée (ajouter --publier pour publier)"
  ok "publication non demandée"
fi

# Étape 7 : résumé
etape 7 "résumé"
echo "Commit      : $SHA"
echo "Lune        : $LIGNE_LUNE"
echo "check.py    : Aucun problème détecté"
echo "run_tests   : code de sortie 0"
echo "Builds      : $BUILD_G ; $BUILD_H"
if [ "$MODE_PUBLIER" -eq 1 ]; then
  echo "Publié      : ${VERSIONS[*]}"
else
  echo "Publié      : rien (mode vérification seule)"
fi
echo "Dossier     : $DIR"
echo "Résultat : toutes les étapes sont passées."
exit 0
