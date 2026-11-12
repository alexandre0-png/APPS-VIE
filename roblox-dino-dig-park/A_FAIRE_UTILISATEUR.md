# À faire par toi (seulement ce que je ne peux pas faire)

Mis à jour : tout le reste (code, visuels, textes, build) est fait. Détail pas à pas : `publication/PUBLICATION.md`.

## 1. Ouvrir et tester dans Roblox Studio
- [ ] Ouvre `DinoDigPark.rbxlx` dans Studio (ou `rojo build -o DinoDigPark.rbxlx`).
- [ ] Game Settings > Security : active « Enable Studio Access to API Services ».
- [ ] Game Settings > Players : Maximum Players = 10.
- [ ] Test > Clients and Servers à 2 joueurs, et vérifie :
  - [ ] la fouille (bouton ⛏, touche F, bouton X de manette), l'éclosion, les achats, le kiosque
  - [ ] les enclos fermés « 🔒 Niveau N » qui s'ouvrent après découverte de dinos
  - [ ] le panneau Aventure, l'énigme du jour (bouton 🧩), les quêtes, le cadeau quotidien, la renaissance
  - [ ] l'énigme change bien le lendemain (ou change l'heure de ton PC pour tester) et la série se cumule
  - [ ] les dinos longs (Spino, Rex Cristal) restent dans leur enclos
  - [ ] la sauvegarde : quitte puis reviens, la progression est conservée
  - [ ] les sons (chemins `rbxasset://` non confirmés) ; remplace-les dans `Config.Sounds` si besoin
  - [ ] l'affichage sur téléphone (menu latéral de 7 boutons)

## 2. Créer les achats dans Creator Hub (Monetization)
Images dans `publication/images/`. Copie ensuite chaque ID dans `src/shared/Config.luau` (champ `id = 0`), puis reconstruis et republie.

| Type | Nom | Prix | Image | Champ à remplir |
|---|---|---|---|---|
| Pass | Revenus x2 | 399 R$ | pass_revenus_x2.png | `Config.Passes.doubleCash.id` |
| Pass | Fouille automatique | 249 R$ | pass_fouille_auto.png | `Config.Passes.autoDig.id` |
| Pass | Éclosion rapide | 299 R$ | pass_eclosion_rapide.png | `Config.Passes.fastHatch.id` |
| Pass | Mode turbo | 199 R$ | pass_turbo.png | `Config.Passes.turbo.id` |
| Produit | Pack de fossiles | 49 R$ | produit_pack_fossiles.png | `Config.Products.fossilPack.id` |
| Produit | Pack de pièces | 99 R$ | produit_pack_pieces.png | `Config.Products.cashPack.id` |
| Produit | Boost x2 (10 min) | 79 R$ | produit_boost_x2.png | `Config.Products.boostPack.id` |
| Produit | Pack de départ | 59 R$ | produit_pack_depart.png | `Config.Products.starterPack.id` |

## 3. Page du jeu
- [ ] Publier le jeu depuis ton compte (File > Publish to Roblox).
- [ ] Coller titre, description FR/EN, genre Tycoon (texte dans `PUBLICATION.md`).
- [ ] Téléverser l'icône `icone_512.png` et les miniatures `miniature_1_heros.png`, `miniature_2_raretes.png`, `miniature_3_fonctions.png`.
- [ ] Répondre au questionnaire de maturité.
- [ ] Vérification d'identité / de compte si Roblox la demande pour la monétisation.
- [ ] Passer l'expérience en Public (Settings > Privacy) après tes tests.
