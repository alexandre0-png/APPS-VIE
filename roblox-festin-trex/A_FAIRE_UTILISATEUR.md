# À faire par toi (seul ce que personne d'autre ne peut faire)

Mis à jour : voir l'historique git. Tout le reste est fait ou automatisé.

## 1. Autoriser les outils de vérification (règle de permission)
Le bac à sable refuse de lancer les binaires téléchargés. Ajoute une règle de permission Bash dans tes paramètres
Claude Code qui autorise `luau-lsp`, `luau`, `stylua`, `selene`, `rojo`, puis préviens-moi : je lance
`tools/check.sh` et `tests/run.sh` et je corrige ce qu'ils trouvent.

## 2. Tester dans Roblox Studio (jamais lancé)
- Ouvrir `dist/FestinDuTRex.rbxlx`, lancer **Play**, lire la fenêtre *Output*.
- Me coller les erreurs (rouge) : je corrige.
- Activer *Game Settings → Security → Enable Studio Access to API Services* pour tester la sauvegarde.
- Tester à 2 joueurs (Test → Local Server) : lancers, festin, marée de sauce, œuf, coffres, reconnexion.

## 3. Identifiants Roblox (pour la publication)
- Créer l'expérience sur create.roblox.com (Creations → Create experience).
- Me donner **Universe ID** et **Place ID**. Je lance ensuite `tools/publish_place.py --go`.
- Vérifier que la clé Open Cloud a : `universe-places:write` (et `universe:write` pour les réglages).

## 4. Créer les achats sur le Creator Dashboard (nom, prix, image)
| Type | Nom | Prix conseillé | Image |
|---|---|---|---|
| Game Pass | VIP Gourmet | 399 R$ | `dist/store/pass_vip.png` |
| Game Pass | Nid agrandi | 199 R$ | `dist/store/pass_nest.png` |
| Game Pass | Super visée | 149 R$ | `dist/store/pass_aim.png` |
| Produit | Sac de pièces (5 000) | 49 R$ | `dist/store/prod_coins_s.png` |
| Produit | Coffre de pièces (75 000) | 449 R$ | `dist/store/prod_coins_l.png` |
| Produit | Pack de 5 œufs | 99 R$ | `dist/store/prod_eggs.png` |

Puis me donner les 6 IDs (ou les coller dans `Config.Monetization`, champs `Id = 0`).

## 5. Téléverser les images et finaliser la page
- Icône `dist/store/icon.png`, miniatures `thumb1-3.png` (Creator Dashboard → Media).
- Ajouter 1-2 vraies captures d'écran prises en Studio (les visuels fournis sont des illustrations).
- Coller le nom et la description de `PUBLISH.md`.

## 6. Conformité Roblox
- Remplir le questionnaire de classification d'âge (Dashboard → Settings → Maturity & Compliance).
- Vérification d'identité / âge du compte si Roblox la demande pour les achats ou la monétisation.
- Passer l'expérience en **Public** quand tu es prêt.
