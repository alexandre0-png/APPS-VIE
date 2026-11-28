# Lot 13 : revue de sécurité courte (duel local, ligues, remise de saison) — 2026-11-27

Périmètre : actions `duelChallenge`, `duelAnswer`, `duelOff`, routage `battleAct` / `battleQuit` vers le duel, boucle de tours, départ d'un joueur, remise de saison dans `pvpState`, assainissement `Data.lua` (`battle.duel`, `battle.pve`, `settings.duelOff`). Revue par lecture du code + tests lupa (`lot13.luau` pur, `lot13_e2e.luau` avec le vrai `Main.server.lua` et `Data.lua`). **Rien n'a été testé dans Studio ni avec un client modifié réel.**

**Bilan : 0 défaut critique ou élevé.**

| Sujet | Risque | État |
|---|---|---|
| Arguments forgés | userId texte / NaN / décimal / absent, table d'acceptation forgée | `duelChallenge` : nombre entier, joueur présent avec session ; `duelAnswer` : table, `from` nombre, acceptation stricte `== true` ; `duelOff` : booléen seulement. Testé (`lot13_e2e`). |
| Défi à distance / en plein vol | Duel lancé de loin, ou pour échapper à une poursuite | Distance serveur ≤ 30 studs (positions des `HumanoidRootPart`), 6 cas de E.2 + vol d'œuf + éclosion + équipe vide, **états des deux relus à l'acceptation**. |
| Harcèlement / spam | Défis en boucle | 1 défi sortant en attente, 3 en attente au plus par cible, cooldown 120 s par paire, délai 20 s, limiteur du dispatcher `RAction`, réglage « refuser automatiquement » (profil). Les cooldowns sont purgés (`Duel.prune`). |
| Double duel / duel + autre combat | Gains doublés, état incohérent | `s.battle = { duel = id }` pour les deux : toutes les gardes existantes (tour, classé, PNJ, équipe, rencontres) refusent ; un seul défi accepté (`book.active`), défis croisés annulés. Minuteur de la tour ignore les duels (`not bt.duel`). |
| Actions de combat | Jouer pour l'adversaire, actions multiples | Le côté vient de la session serveur (`D.find`), pas du client ; `Battle.validate(st, side, act)` ; une seule intention par tour. Action invalide : refusée sans casser le tour. |
| Double récompense | Fin déclenchée deux fois (abandon + départ + échéance) | `D.matches[id] = nil` et `s.battle = nil` AVANT tout paiement ; second appel sans effet. |
| Collusion | Deux comptes complices qui farment | 10/jour, 3/paire/jour, départ / abandon avant 3 tours = 0 pièce, partant jamais payé ; montant = 1 min de revenu (15 s au perdant), aucun trophée, aucune XP de passe ; XP de pet seulement si payé. Gain maximal par jour négligeable face au jeu normal. |
| Téléportation | Duel utilisé pour se déplacer | Placement sur le sable puis **retour à la position d'avant** ; personnage figé ; voyage rapide refusé pendant le duel ; anti-triche de vitesse suspendu 2 s seulement à chaque placement. |
| Départ en plein duel | Fuite mémoire, défaite évitée en quittant | `L15.duelLeave` appelé par `PlayerRemoving` avant la sauvegarde : forfait (défaite sauvegardée, testé), défis retirés (adversaires prévenus), aucune entrée restante (`book.active`, `pending`, `matches`). |
| Remise de saison | Récompense de saison payée deux fois | Inchangé : `pv.season` mis à jour dans le même bloc que le paiement (une fois par saison). Palier 1500 = 1 œuf Mythique (base -> sac -> coffre de débordement, un seul crédit) + potion 30 min. |
| Données | Profil corrompu | `battle.duel` (entiers bornés, 20 paires au plus, clés ≤ 20 caractères), `battle.pve`, `settings.duelOff` (booléen) assainis ; anciens profils relus sans perte (testé). |
| Robux | Avantage payant | Aucun produit, pass ou boost ne touche au duel ; les stats de combat ne s'achètent pas (règle du lot 12). |

## Limites connues (non bloquantes)

- Un duelliste qui réinitialise son personnage n'est plus figé (le duel continue par l'interface) ; il est ramené à sa position de départ à la fin.
- Les spectateurs reçoivent la vue complète des deux équipes (PV, types) : information publique, sans intérêt de triche.
