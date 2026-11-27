# Lot 15 : revue de sécurité (économie, remotes, mémoire) — 2026-11-27

Périmètre : tout ce que le lot 15 ajoute ou modifie dans `Main.server.lua` (bloc « Lot 15 », hooks de `hatch`, `qp`, `battleFinish`, calendrier, `ProcessReceipt`),
`Data.lua` (v12), `Client.client.lua`, modules `Npc.lua` / `Rewards.lua`. Revue par lecture du code + tests (`tests/lot15.luau`, `tests/lot15_e2e.luau` avec le vrai
`Main.server.lua`). **Rien n'a été testé dans Studio ni avec de vrais joueurs malveillants.**

## Failles trouvées et corrigées pendant l'intégration

| # | Faille | Gravité | Correction |
|---|---|---|---|
| 1 | `Config.EVENTS` (événements serveur) aurait été **écrasé** par la table `EVENTS` du lot 15 en fusionnant `Lot15Data` dans `Config` : les événements serveur (ruée vers l'or…) auraient lu des données invalides. | Haute (casse du jeu) | Renommé `TIMED_EVENTS` ; test « Config.EVENTS intact ». |
| 2 | Calendrier : la place pour l'œuf était vérifiée AVANT la sauvegarde (qui attend le DataStore) ; si le joueur remplissait base et sac pendant ce temps, `storeEggs` échouait et **l'œuf était perdu**. | Moyenne (perte) | Repli de `giveEgg` (conversion en pièces, comme avant le lot) : jamais perdu, jamais doublé. |
| 3 | Le client aurait pu envoyer `{ how = "product" }` à l'action `daily` pour **sauver sa série sans payer**. | Haute (économie) | `actions.daily` n'accepte que `nil`, `"quest"`, `"reset"` ; `"product"` n'est appelé que par `ProcessReceipt` (reçu StreakRestore). Testé de bout en bout. |
| 4 | Échange de PNJ refusé faute de place calculé SANS compter les emplacements libérés par les doublons donnés : refus injustifié (pas une faille, mais une incohérence). | Faible | Place = libres + emplacements donnés (dans la capacité) + sac. |
| 5 | Combat de Kaï gagné base et sac pleins : l'Œuf Mythique garanti aurait pu être perdu. | Moyenne | Combat refusé tant qu'il n'y a pas une place (base ou sac) ; si le joueur remplit tout pendant le combat, repli en pièces (50 % de la valeur de l'œuf). |

## Contrôles en place (vérifiés)

- **Offres de PNJ** : générées par le serveur (`Npc.encounter`), identifiant unique, liées au `userId`, valables 60 s, à usage unique (retirées du carnet puis mémorisées : rejeu = « used ») ; le client n'envoie que `{ id, action, confirm2 }` (type et longueur vérifiés). Testé : autre joueur refusé, rejeu refusé, charges utiles invalides ignorées, 10 000 offres sans violation de F.4 (aucun pet de rareté >= 6, équipé, d'équipe, de défense, muté Arc-en-ciel+, Géant+, ni dernier exemplaire).
- **Échange appliqué en une fois** : revalidation contre l'inventaire ACTUEL (`Npc.accept` : emplacements, espèce, taille, mutation, règles F.4, pièces), puis pièces, retrait des pets, don (espèce dans l'emplacement libéré, œuf via `storeEggs` atomique) sans aucune attente entre les étapes : pas de fenêtre de duplication. Sauvegarde lancée juste après (au pire, une panne serveur annule l'échange ENTIER : rien n'est doublé).
- **Combats de PNJ** : résultat calculé par le moteur `Battle` du serveur ; `Npc.resolve` à usage unique ; abandon = défaite (rien n'est perdu, +5 XP) ; départ du joueur = carnet libéré, aucun gain.
- **Quotas** : compteurs `npc.day/trades/fights/enc/champ` et `nextAt` absolu dans le profil (sauvegardés), consommés dès l'apparition : se reconnecter / changer de serveur ne relance rien (testé). Refus : 10 min de calme ; 3 refus du même PNJ : parti pour la journée.
- **Série de 7 jours** : jour décidé par le serveur (`os.time() // 86400`) ; réclamation atomique (`Rewards.streakClaim` : en cas de base et sac pleins, rien n'est modifié) ; une fois par jour ; raretés par nom, jamais Secret / Exclusif / Divin.
- **Reçus** : `StreakRestore` passe par le circuit existant (`receipts`, `pendingReceipts`, `PurchaseGranted` après sauvegarde) ; livré seulement si la série est vraiment à sauver et pas déjà sauvée cette semaine (sinon `NotProcessedYet`, rien n'est livré). ID 0 = achat désactivé.
- **Sac d'œufs** : 10 places, assaini à la lecture (entiers 1..10 raretés) ; `bagTake` et `storeEggs` atomiques ; grand livre de 3 000 actions aléatoires : œufs accordés = œufs en base + sac.
- **Quêtes bonus / semaine, plumes** : drapeaux de réclamation posés après le rangement réussi ; plafonds de plumes par jour ; l'Œuf Exclusif refusé tant que la rareté n'a aucune espèce (`notLive`).
- **Remotes** : `Npc` est serveur -> client seulement (aucun `OnServerEvent`) ; toutes les demandes passent par `Action` (anti-spam 0,08 s, `pcall` par action) ; `npcOff` n'accepte qu'un booléen ; `weeklyClaim` que 5 ou 7.
- **Aucun Robux dans un dialogue de PNJ, aucun échange entre joueurs** : les offres ne contiennent aucun champ produit / cible (contrôlé par `Npc.violations`) ; test du texte envoyé au client.
- **Mémoire** : carnets d'offres par joueur vidés au départ (`L15.books[player] = nil`) ; offres expirées balayées toutes les 5 s ; liste des identifiants utilisés plafonnée à 64 ; côté client, un seul modèle de PNJ à la fois, détruit à la fin (Debris), tweens et `NumberValue` détruits.
- **Migration v12** : idempotente (sanitize des modules) ; profils corrompus assainis ; profil d'une version plus récente jamais écrasé (testé).

## Risques résiduels (non corrigés, documentés)

- Une panne de serveur entre une action et la sauvegarde suivante (au plus 60 s) annule l'action et ses compteurs (comme partout dans le jeu) : un quota de PNJ consommé peut alors revenir. Pas de duplication possible.
- Le +20 % d'attaque du type « en forme » et le poids x2 de l'espèce vedette sont calculés par le serveur ; aucun moyen client de les influencer.
- `Config.BELT.interval` est modifié en mémoire par le serveur pendant le week-end chanceux (pas de risque client ; à surveiller si d'autres modules lisent cette valeur).
