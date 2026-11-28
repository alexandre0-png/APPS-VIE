# Intégration des lots 11 et 12 (préparés par la gestion) : ordre et arbitrages

À faire par la session Jeu 2 APRÈS le commit « Lot 16 ». Un commit non-WIP par lot, Lune lancé avant chaque push. Chaque dossier a son README « Brancher » : le suivre à la lettre.

## Ordre
1. **Lot 11** : `lots-prep/chipe-11/` (bestiaire 78 espèces : Bestiary.lua, SPECIES_TYPE/SKILL à 78, repli procédural, IDs Blender). Commit « Lot 11 intégré ». Après ce lot, les offres Secret/Exclusif/Divin du lot 9 (masquées tant que les espèces n'existent pas) peuvent s'afficher : vérifier le test et le repli du jour 30 (Secret 15 %).
2. **Lot 12A** : `lots-prep/chipe-12a/` (Battle.lua refait : 9 types, charge 0..5, spécial, 40 tours, DAMAGE_MUL 1,6) + patches `Config.TYPE_WEAK.patch` et `run.luau.patch`.
3. **Lot 12B** : `lots-prep/chipe-12b/` (BattleRewards, PetXp, BattleUi, patch Data) + ligne `run.luau` `{ "lot15", "lot15_e2e", "lot12b" }`. Commit commun « Lot 12 intégré » pour 12A + 12B (même Main).

## Arbitrages (décidés par la gestion)
- **Une seule source d'XP** : `PetXp` (exposant 1,1, MAX_XP 9 734) ; supprimer ou faire déléguer `Battle.addXp`/`levelFromXp` vers `PetXp`. `Battle.unit` multiplie pv/attaque par `PetXp.statMul(PetXp.level(slot.x))`.
- **STATS** : r=1 reste 50/8/12 (lot 9, test existant) ; r=3..7 inchangés (ancienne formule) ; r=2 et r=8..10 : valeurs du code.
- **DAMAGE_MUL 1,6** conservé (durée moyenne 8–14 tours, appliqué aux deux camps).
- **`Config.TYPE_WEAK`** : appliquer le patch d'une ligne (cohérence avec la matrice).
- Hook `giveEgg` du README 12B : chercher une place libre AVANT, ne jamais appeler l'ancien giveEgg quand la base est pleine.
- **Serveurs mixtes** : ne pas mélanger lot 15 et lot 12B en ligne (pendingPick perdu) : publier les deux lieux d'un coup (ce que fait la gestion).
- Après 11 et 12 : `roblox/CHANGELOG`, `LOT12_ECARTS.md`, revue sécurité courte sur `battlePick`, `pendingPick`, XP.

## À tester dans Studio (liste des READMEs)
Choix de 3 cartes, boss = œuf, reconnexion avant 15 s, spécial au 6ᵉ tour, texte d'efficacité, tour 35/40/45, mobile 360 px.
