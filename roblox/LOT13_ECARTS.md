# Lot 13 : écarts et décisions d'intégration (duel local, ligues, remise de saison) — 2026-11-27

Préparation de la gestion : `lots-prep/chipe-13/` (branche `claude/jolly-cannon-w2wx5h`, lecture seule) testée sur le lot 15 (91f6907). Appliquée sur la tête « Lot 11 + 12 intégrés » (f7ff0f5) : 3 patchs sans rejet (décalages Config +56, Data +15/+57, Main +618). **Rien n'a été joué dans Studio.**

## À VALIDER (provisoire)

- **Palier 1500 trophées de la saison (Champion)** : 1 000 000 pièces + œuf Ultra Rare + potion + titre « Champion de la saison n ». Le montant en pièces a été **inventé par la préparation** (absent de la spec E.4) : gardé tel quel, marqué `provisional = true` dans `Config.LEAGUE_SEASON.rewards` et commenté « PROVISOIRE ». À confirmer ou corriger par l'utilisateur (une seule valeur à changer).

## Ce que la préparation ne branchait pas et qui a été écrit à l'intégration

| Élément | Décision |
|---|---|
| Boucle de tours | `L15.duel` dans `Main.server.lua` (bloc « Duel local », une seule variable locale `D`, rangée dans `L15.duel`). Tour de 10 s (`Config.DUEL.turnSeconds`) ; chaque duelliste envoie UNE intention par tour (`battleAct`, routé vers le duel) ; dès que les deux ont choisi, le tour est résolu tout de suite ; sinon, à l'échéance, action par défaut = attaque. Moteur : `Battle.turn(st, actionA, actionB)` du lot 12A (9 types, charge 0..5, spécial, 40 tours), camp A = défieur, camp B = défié (jamais l'IA). |
| Forfait | `Duel.noteTurn` : 2 tours sans action = forfait ; les deux inactifs = duel annulé (ni V/D ni pièces). |
| Vue du défié | `Duel.mirrorView` / `Duel.mirrorEvents` (ajoutés au module pur, testés) : chacun voit son équipe en camp 1, `BattleUi` les affiche sans autre changement. |
| Sable et caméra | Les deux duellistes sont placés à ±10 studs du centre du colisée (`Config.Map2.arena`), face à face, personnage figé (`Anchored`) pendant le duel, puis ramenés à leur position d'avant le duel. Pas de voyage rapide pendant un duel. Caméra cliente « Scriptable » de côté sur le sable (fondu 0,8 s), rendue à la fin. |
| Spectateurs | Joueurs à moins de 90 studs du centre du colisée (`Config.DUEL.spectatorRange`) : bandeau `duelWatch` (noms, PV restants des deux équipes, tour, vainqueur), recalculé à chaque tour (un joueur qui s'approche le voit). |
| UI de la demande | `BattleUi` : carte « ⚔️ X te défie en duel ! » avec **Accepter / Refuser** et compte à rebours ; fermée à l'expiration, à l'annulation (`duelAskEnd`) ou au départ du défieur. |
| Bouton « Défier » | Invite `ProximityPrompt` **locale** (touche **G**, manette Y, maintien 0,4 s, 28 studs) sur chaque autre joueur ; touche distincte de E pour ne jamais masquer les invites des œufs et des nids. Menu Plus : « Défier en duel » (joueur le plus proche) et le réglage. |
| Réglage « Refuser automatiquement les duels » | Nouveau champ `settings.duelOff` (Data, facultatif, sans changement de version). **Le réglage PNJ `npc.off` ne bloque pas les duels** (sens différent : un PNJ qui interpelle vs un joueur qui propose) ; décision prise en autonomie. |
| Intro B.4 | Le serveur envoie `intro = { me, foe }` (ratio de duel, ligue, trophées) ; `BattleUi` appelle `IntroPlan` en mode `duel`. Ligue aussi passée pour le classé (état client `battle.league`). |
| `battle.pve` | Mis à jour dans `battleFinish` pour la tour ET les combats de PNJ (les deux sont du PvE) ; la préparation ne parlait que de la branche non-PvP. |
| Remise de saison (E.4) | Branchée dans `pvpState` : `Duel.seasonReset` = max(300, floor(t × 0,6)) au-delà de 300 (t ≤ 300 inchangé) au lieu de `floor(t / 4)` ; récompense par `Duel.seasonReward(Config.LEAGUE_SEASON.rewards)` (paliers 100 à 1500). `Config.PVP.rewards` / `Config.pvpSeasonReward` restent (tests historiques), mais ne sont plus lus par `Main`. Titre « Champion de la saison n » : affiché dans la notification, **pas stocké** (aucun champ de profil de plus). |

## Validations serveur ajoutées (au-delà des 6 cas de E.2)

- Vol d'œuf en cours (`holds`) et grande éclosion (`cineUntil`) : nouveaux refus `flying` / `cinematic` dans `Duel.canChallenge`.
- Équipe de pets vide (défieur ou défié) : refusé à l'envoi ET à l'acceptation.
- Défié avec `duelOff` : refusé avant tout enregistrement.
- Serveur « ranked » (lot 14) : duel impossible (occupé).
- Session en cours de départ (`s.leaving`) : occupé.

## Anti-collusion (même compte / même IP impossible à détecter côté Roblox)

- Quotas de `Duel.settle` : 10 duels récompensés par jour et par joueur, **3 par paire d'adversaires et par jour**.
- **Ajout** : un duel terminé par départ ou abandon avant 3 tours (`Config.DUEL.earlyMinTurns`) ne paie personne (`Duel.payable`) ; le joueur qui part n'est jamais payé. Ratio V/D et quotas restent comptés.
- XP de pet : seulement pour un duel effectivement payé (donc sous les quotas), source `pvp` de `PetXp` (plafonnée par gain et au niveau 20). **Aucune XP du passe de combat, aucun trophée, aucune quête de la semaine** pour un duel.
- Aucune récompense en Robux, aucun produit ni pass lié au duel.

## Non fait (hors périmètre ou décision)

- Badge de ligue au-dessus de la tête, modèles `arena.podium / banner / board` : non faits (pas de modèles fournis ; le texte de ligue est dans l'intro et l'état client).
- Ordre des deux `PlayerRemoving` : supprimé le gestionnaire séparé de la préparation ; le forfait est appliqué par le gestionnaire principal (`L15.duelLeave`) **avant** la sauvegarde de départ (défaite du partant écrite et sauvegardée, testé).
- Fermeture du serveur pendant un duel (`BindToClose`) : aucun résultat appliqué (duel amical, rien à perdre).
