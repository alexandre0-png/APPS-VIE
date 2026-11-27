# Lots 11 + 12 : revue de sécurité courte (cartes de récompense, XP de pet, œufs donnés) — 2026-11-27

Périmètre : `actions.battlePick`, `battle.pendingPick` (tirage enregistré dans le profil), XP de pet (`PetXp`, seule source), hook `giveEgg` des cartes Œuf
(base, sac d'œufs, coffre de débordement), boosts de cartes (`income2`, `luck10`, `speed15`, `xp2`), assainissement `Data.lua`. Revue par lecture du code + tests
lupa (`lot12b.luau` avec le vrai `Data.lua` / `Main.server.lua`, `lot15_e2e`, `lot16_e2e`). **Rien n'a été testé dans Studio ni avec un client modifié réel.**

**Bilan : 0 défaut critique ou élevé restant.**

## Points vérifiés

| Sujet | Risque | État |
|---|---|---|
| `battlePick` (remote `RAction`) | Arguments forgés, rejeu, double clic | `arg` doit être une table, `id` texte de 64 caractères au plus, `i` nombre ; tout est revalidé par `BattleRewards.claim` (identifiant du tirage en cours, index 1..3 entier). Index ou id invalide : rien n'est consommé. `pendingPick = nil` AVANT `grant` : un second clic (ou le délai serveur de 15 s qui tombe en même temps) ne trouve plus rien. Limitation de fréquence du dispatcher `RAction`. |
| Valeur des cartes | Client qui choisit le montant | Les cartes sont tirées et chiffrées par le SERVEUR (`BattleRewards.offer`, graine `rng` serveur, revenu `income(s)` serveur) ; le client ne renvoie qu'un index. `pendingPick` n'est jamais exposé par `snapshot` (cartes envoyées seulement par `{ k = "pick" }`). |
| Création du tirage | Combat non gagné, combat rejoué | `offerPick` n'est appelé qu'après une victoire déclarée par le serveur (`battleFinish` : `s.battle` vidé avant tout paiement ; `L15.fightEnd` : `Npc.resolve` à usage unique). Tour : seulement si premier passage OU sous le quota quotidien (`TW.dailyRepeats` + tickets d'arène du lot 16). Un nouveau tirage remplace l'ancien seulement via `BattleRewards.offer` (l'ancien non réclamé reste prioritaire : voir `lot12b`). |
| Reconnexion | Relancer pour retirer d'autres cartes | Le tirage est dans le profil (sauvegardé) : à la connexion, `sendPick` renvoie LE MÊME tirage avec le temps restant ; échu = première carte donnée d'office. Profil corrompu : `BattleRewards.sanitizePending` (3 cartes de catégories distinctes, montants bornés) sinon `nil`. |
| Serveurs mixtes | `pendingPick` perdu si un serveur du lot 15 sauvegarde après | Pas de duplication possible (au pire perte d'un tirage) ; publier les deux lieux d'un coup (décision de la gestion). |
| XP de pet | Achat / reçu / cadeau donnant de l'XP ; débordement | Une seule source : `PetXp` (liste blanche `pve`, `pvp`, `npc`, `card` ; tout le reste vaut 0) ; montant calculé serveur (`PetXp.combat`, étage serveur) ; `MAX_AWARD` par gain, `MAX_XP` 9 734 (niveau 20) ; `addToTeam` ignore les index non numériques, les doublons et les emplacements sans pet. `ProcessReceipt` ne touche ni `.x` ni les STATS (test `lot12a`), aucun produit ne mentionne l'XP (test, mot entier). `Data` borne `slot.x` (`PetXp.sanitize`). Boost x2 : série (`xp2Until`) OU carte (`boosts.xp2`), jamais cumulés. |
| Farm d'XP par défaites | Perdre en boucle à la tour | 5 XP par défaite (3 contre un PNJ) contre 20 + 5 x étage par victoire : un combat dure plusieurs tours de 10 s ; gain négligeable, plafonné au niveau 20 (x1,285 au plus). Accepté. |
| Carte Œuf, base pleine | Ancien `giveEgg` qui paie la moitié du prix ; perte d'œuf | Hook `L15.pickHooks` : place libre cherchée AVANT ; base libre -> `giveEgg` ; base pleine -> `Lot7.L16.storeEgg` (sac d'œufs du lot 15, puis coffre de débordement du lot 16, sans limite) : l'œuf n'est jamais perdu ni converti, et l'ancien `giveEgg` (demi-prix) n'est jamais appelé quand la base est pleine. La conversion en pièces de `BattleRewards.grant` ne reste qu'en garde (hook absent). Message « rangé dans ton sac » / « coffre de débordement ». |
| Boosts de cartes | Durées infinies, clés inventées | `BattleRewards.applyBoost` (durée de la carte serveur) ; `sanitizeBoosts` : 4 clés connues, entiers bornés ; lus seulement aux endroits prévus (`gmult` x2, `luckPoints` = même effet que la potion, `speedMul` +15 % aussi appliqué à la tolérance anti-triche de vitesse, `PetXp.boostMul`). |
| Délai de 15 s | `task.delay` sur un joueur parti / session remplacée | Le rappel vérifie `s.player.Parent`, `sessions[s.player] == s` et l'identifiant du tirage avant d'attribuer : aucun octroi sur une session morte, aucune fuite (une seule closure par tirage, libérée après 16 s). |
| Espèce Exclusif de saison (lot 11 x 16) | Contournement par nom | `Season` donne l'espèce par NOM ET rareté Exclusif seulement ; sinon trophée de repli (testé). Pose : place libre sinon œuf de la rareté rangé base / sac / débordement. |
| Œufs Secret / Exclusif / Divin / Peu commun (Robux) | Vente d'un œuf sans espèce | `Shop.status` masque et `Shop.canBuy` refuse toute rareté sans espèce publiée (`Config.tierLive`) ; avec le bestiaire les 10 raretés sont publiées (testé avec et sans bestiaire). |

## Limites connues (non bloquantes)

- `PetXp.carry` (report de l'XP au vol) n'est pas branché : aujourd'hui seuls des ŒUFS se volent (pas de pet volé), donc rien à reporter.
- L'XP de Dresseur (`PetXp.trainerAdd`) n'est pas alimentée par `Main` : champ `trainer` assaini et sauvegardé, sans effet de jeu (prévu plus tard).
- Le niveau de pet n'est pas envoyé dans `snapshot` (l'inventaire ne l'affiche pas encore) ; il est visible dans la vue de combat (`Battle.view`).
