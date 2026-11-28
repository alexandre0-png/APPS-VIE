---
type: outils
---
# Outils
- Rojo, stylua, selene, Lune : binaires dans `/tmp/claude-0/cargo-out/bin` (à remettre dans le PATH). Installation : `scripts/setup-roblox-toolchain.sh`. Vérification d'un jeu : `scripts/check-game.sh <jeu>`.
- Python : tests `unittest` et `lupa`.
- FFmpeg 6.1.1 présent dans le conteneur : génération de sons (`lavfi`, export OGG).
- Blender : `pip install bpy` dans un venv (testé, fonctionne). Script : `scripts/blender_make_models.py <dossier_sortie>`, export FBX.
- ElevenLabs : non utilisé (l'utilisateur a refusé de donner la clé).
- MCP de Roblox Studio : installé sur le PC de l'utilisateur (Claude Code local 2.1.329, portée « user »). Inaccessible depuis le cloud.
- Hôtes bloqués depuis le sandbox : develop.roblox.com, github.com (téléchargements), obsidian.md, figma.com.
- Application Claude de bureau de l'utilisateur : pas d'option Remote Control.
