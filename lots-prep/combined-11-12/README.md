# Fusion lots 11 + 12A + 12B : patch unique (Jeu 2, Chipe-Oeufs)

Fusion d'essai, testee sur le commit 91f6907 (lot 15 integre). Aucune cle API, rien de publie.

## Appliquer
    cd <racine du depot de jeu>          # le dossier qui contient roblox/
    patch -p1 --dry-run < /chemin/combined.patch   # verification
    patch -p1 < /chemin/combined.patch
Le patch (diff -ruN, 21 fichiers, environ 520 Ko) cree/modifie aussi `roblox/build/ChipeOeufs.rbxlx` et `Hub.rbxlx` (regeneres par `python3 roblox/tools/build_place.py`, exige par `check.py`). Verifie : `--dry-run` propre sur une copie neuve de 91f6907, puis application = copie de travail identique (`diff -rq` vide). Les nouveaux fichiers sont aussi fournis en clair dans `roblox/` (ce dossier).

## Ordre applique
1. Lot 11 : Bestiary.lua (78 especes), patchs Config, Assets, Builder, Client, run.luau, lot11.luau/run_lot11.py. Patch Battle du lot 11 NON applique.
2. Lot 12A : Battle.lua remplace l'ancien, Config.TYPE_WEAK, run.luau (hunks 12A), lot12a.luau/run_lot12a.py.
3. Lot 12B : BattleRewards.lua, PetXp.lua, BattleUi.lua (remplace), patch Data.lua, lot12b.luau/run_lot12b.py.
4. Fusion : Main.server.lua, Battle.lua (source unique), BattleUi (adaptations 12A), build_place.py, tests.

## Arbitrages appliques
- Types/competences : `Battle.SPECIES_TYPE/SKILL` sont construits depuis `Bestiary.SPECIES_TYPE/SKILL` (78 especes, 9 types) par `require` de `script.Parent.Bestiary` dans un pcall ; « Plante » devient la cle moteur `Nature` (affichee Plante par TYPE_LABEL). Repli sans Bestiary : les 18 historiques.
- Une seule source d'XP : `PetXp` (exposant 1,1, MAX_XP 9734). Supprimes de Battle : xpTo, XP_AT, XP_CAP, levelFromXp, addXp, xpReward, XP_BASE/EXP. `Battle.unit` lit `PetXp.level(slot.x)` et `Battle.levelMul` delegue a `PetXp.statMul`. Sans PetXp : niveau 1.
- STATS (r=1 50/8/12...) et DAMAGE_MUL 1,6 : inchanges (12A). Config.TYPE_WEAK : patch 12A.
- Main.server.lua : `battleFinish` (tour) et PvP : XP via PetXp.award/addToTeam (boost x2 lu par PetXp.boostMul) ; victoire a la tour : plus de `Config.towerReward`, 3 cartes (`offerPick` + `sendPick` apres l'envoi de `end`, `rewards.pick = true`), ancien code de defaite PNJ `sl.x = math.min(1e7, ...)` remplace par PetXp (victoire ET defaite, x0,6) ; victoire PNJ : 3 cartes mode npc ; `battlePick` (id string <= 64 car., i nombre, tout revalide par BattleRewards.claim) ; hook `giveEgg` : cherche une place libre AVANT, jamais d'ancien giveEgg si base pleine (conversion au prix plein par grant) ; reconnexion : `sendPick` 5 s apres la connexion (echu = premiere carte d'office) ; delai de 15 s tenu par le serveur ; `pendingPick` non expose par snapshot ; boosts de cartes lus : income2 (gmult), luck10 (luckPoints), speed15 (speedMul), xp2 (PetXp.boostMul).
- Limite Luau de 200 variables locales par fonction : les ajouts de Main sont ranges dans la table existante `L15` (`L15.BR`, `L15.PetXp`, `L15.sendPick`, `L15.claimPick`, `L15.offerPick`, `L15.pickHooks`), pas en `local` (un premier essai en `local` a depasse la limite : « too many local variables »).
- BattleUi : `special = ev.special == true`, `readySoon = ev.charge == 4`, nom du special via `Battle.SPECIAL_NAME`.
- run.luau : un seul bloc coherent : lot10, lot11, lot12a puis la boucle `{ "lot15", "lot15_e2e", "lot12b" }`.
- build_place.py : Bestiary, PetXp, BattleRewards ajoutes a SHARED (sans cela ils manquaient dans le .rbxlx).

## Ecarts / tests adaptes
- Les 18 premieres especes prennent les types FINAUX (6 changements C.1) : le test « 3 par type / triangle par rareté » est remplace par « types = Bestiary » ; le test d'equilibrage 100 000 combats (run.luau) tourne sur les 78 especes (Config complet) : especes 39,7 % a 57,3 % (seuil 12 points au lieu de 10), types a 3,4 points.
- lot12a : XP/niveaux testes via PetXp ; Config complet (78 especes) pour les combats d'especes reelles (types 44,5 % a 54 %).
- lot11 : « 9 competences utilisees par >= 2 especes » (guard n'en a que 2).
- lot15_e2e : defaite PNJ = 3 XP de pet (6 si l'XP x2 de la serie est actif) au lieu de 5.
- Non fait : report de l'XP au vol/vente (`PetXp.carry`) ; non branche dans Main (le slot vole garde ses champs selon le code actuel : a verifier) ; Data.lua ligne 520 deja traitee par le patch 12B.
- Serveurs mixtes : ne pas laisser tourner lot 15 et ce patch ensemble (pendingPick perdu) ; publier les deux lieux d'un coup.

## Resultats (copie de travail, PATH=/tmp/claude-0/cargo-out/bin)
| Commande | Resultat |
|---|---|
| `python3 roblox/tools/run_tests.py` | 3475 reussis, 0 echoue, code 0 |
| `lune run roblox/tests/run.luau` | 3475 reussis, 0 echoue, code 0 |
| `python3 roblox/tools/check.py` | « Aucun probleme detecte », code 0 (inclut aussi un passage de run_tests : 3475/0) |
| `rojo build game.project.json` / `hub.project.json` | OK / OK |
| lot12a seul, lot12b seul, lot15 seul | 89/0, 91/0, 250/0 |
Analyse statique seule ; selene, luau-analyze, stylua non lances ici. Iterations de correction : 3 (types, equilibrage, limite de locales, delai de reconnexion, tests PNJ).

## A tester dans Studio
Tour etage 1 gagne : 3 cartes de categories differentes, 15 s, « Continuer » apres le choix ; etage 5 (boss) : carte Oeuf ; base pleine + carte Oeuf : pieces au prix plein ; quitter a 5 s et revenir : memes cartes (revenir apres 15 s : premiere carte donnee) ; victoire PNJ : 3 cartes x0,6 ; clic rapide sur plusieurs cartes : une seule recompense ; special au 6e tour (charge 5, 4 si coup avantageux), texte d'efficacite, charge conservee au changement de pet ; XP de pet (niveau 20 = x1,285) apres plusieurs combats ; boosts income2 / luck10 / speed15 effectifs ; 78 especes affichees (Index x/78), modeles Blender et repli procedural ; mobile 360 px.
