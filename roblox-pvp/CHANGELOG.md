# Journal des changements — Arène des Légendes

## V1.7 — saisons
- `SeasonLogic` + `SeasonService` : points de saison, 10 paliers, titre de champion, remise à zéro au changement de saison ; onglet « Saison ».
- Barre d'onglets défilante (8 onglets). `A_FAIRE_UTILISATEUR.md` : ce qui reste à votre charge.

## V1.6 — histoire, héros, mode
- `Lore` + `StoryService` : prologue, 4 héros (aura, teinte, nom sur la plaque), Chronique de 5 chapitres, onglet « Héros ».
- Éliminations en désintégration colorée (aucun sang) ; mode « Roi de la tour ».

## V1.5 — préparation de publication
- `tools/publish.sh` + `tools/apply_ids.py` (testé) : Id d'achats injectés depuis `publication/ids.json`, puis `rojo build`.
- Nouvelle quête quotidienne « Pris de rage » (10 quêtes au total).

## V1.4 — audit
- Plaque de nom : connexions coupées à la disparition du personnage (fuite corrigée).

## V1.3 — bots, accueil
- Bots d'arène (`BotService`, `BotLogic`) : complètent jusqu'à 4 combattants, actifs seulement en manche, récompense réduite.
- Astuces d'accueil selon l'appareil.

## V1.2 — durcissement, graphismes, animations
- Sauvegarde sans perte (attente de l'autosave, `Discard` si départ pendant le chargement), limites Join/Leave, arguments typés, intervalle global entre tirs.
- Bloom, colorimétrie, rayons de soleil, bannières d'équipe, anneau runique, braises, fanions, lucioles, étincelles d'impact, animations d'interface.
- Gestes et sons propres à dague, katana, Souverain, marteau.

## V1.1 — monétisation
- 3 Game Passes et 3 Developer Products (Id à 0 = désactivés), reçus idempotents sauvegardés avant validation.
- Images (icône + 3 miniatures) et `publication/PUBLICATION.md`.

## V1.0 — jeu complet
- Hub, arène, 10 armes, manches FFA / équipes, progression, quêtes, cadeau quotidien, classement, UI, sauvegarde.

## Décisions techniques
- Chaîne de vérification maison (`tools/`) car `luau-analyze` n'accepte pas les définitions Roblox : requires réécrits en chemins, stubs `any`,
  contrôle des noms d'API contre `globalTypes.d.luau`, faux environnement Roblox pour tester les vrais modules serveur.
- Tests exécutés avec l'interpréteur `luau` (Lune n'est pas installé).
- `stylua`, `selene`, `rojo` : non installés ; le téléchargement de binaires/sources externes a été refusé par l'environnement. Je n'ai pas
  tenté de contourner ce refus (ni `cargo install`). Configs prêtes : `stylua.toml`, `selene.toml`, `default.project.json`.
- Pas de verrou de session DataStore (limite connue, rare).

## Reste à faire par vous
`rojo build`, test à deux joueurs dans Studio, création des achats et saisie de leurs Id, remplacement des visuels par de vraies captures,
publication (compte, vérification d'identité, questionnaire d'âge).
