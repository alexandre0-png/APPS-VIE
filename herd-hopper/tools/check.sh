#!/usr/bin/env bash
# Vérifications locales. Les outils absents sont signalés, jamais ignorés en silence.
set -u
cd "$(dirname "$0")/.."
status=0
run() { echo "== $1"; shift; "$@" || status=1; }
if command -v stylua >/dev/null; then run stylua stylua --check src; else echo "== stylua : NON INSTALLÉ (non exécuté)"; fi
if command -v selene >/dev/null; then run selene selene src; else echo "== selene : NON INSTALLÉ (non exécuté)"; fi
if command -v rojo >/dev/null; then run "rojo build" rojo build -o /tmp/SauteTroupeau.rbxlx; else echo "== rojo : NON INSTALLÉ (non exécuté)"; fi
if command -v lune >/dev/null; then run "compilation Luau" lune run tools/lune/syntax.luau; run "tests Lune" lune run tools/lune/run.luau; else echo "== lune : NON INSTALLÉ (non exécuté)"; fi
python3 tools/build_rbxlx.py || status=1
(cd tools/sim && [ -d node_modules ] || npm install --silent) 
for s in A B C CLIENT UNIT; do run "simulation $s" bash -c "cd tools/sim && node run.js $s | tee /dev/stderr | grep -q 'ERREURS LUA:	0'"; done
exit $status
