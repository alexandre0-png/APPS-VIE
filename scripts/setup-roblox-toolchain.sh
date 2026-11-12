#!/usr/bin/env bash
# Installe la chaîne d'outils Luau dans ~/.roblox-tools (idempotent). Requiert cargo et crates.io.
set -eu
ROOT="$HOME/.roblox-tools"
[ -x "$ROOT/bin/stylua" ] || cargo install --locked --features luau --root "$ROOT" stylua  # sans --features luau, += et // sont rejetés
for crate in selene lune rojo; do
  [ -x "$ROOT/bin/$crate" ] || cargo install --locked --root "$ROOT" "$crate"
done
echo "OK: $(ls "$ROOT/bin" | tr '\n' ' ')"
