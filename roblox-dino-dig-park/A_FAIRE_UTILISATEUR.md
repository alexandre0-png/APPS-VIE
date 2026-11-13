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
  - [ ] les cinématiques (réglables dans `Config.Cinematics`) : intro de ~22 s au premier lancement puis mini tutoriel, premier dino rare (~12 s), ouverture des enclos 5 et 6 (~12 s) ; vérifie que le bouton « Passer ⏭ » (ou Entrée / bouton B) rend bien la caméra, que les angles ne traversent pas les bâtiments, et que les textes se lisent sur téléphone
  - [ ] les animations (dans `Config.Animations`, chacune désactivable) : respiration et sauts des dinos, coup de pelle, fossile qui sort de terre, pièces du kiosque, onde d'arrivée d'un bâtiment, barrières qui s'ouvrent, fondu des fenêtres, compteurs qui défilent ; vérifie la fluidité sur téléphone et coupe celles qui ralentissent
  - [ ] l'énigme change bien le lendemain (ou change l'heure de ton PC pour tester) et la série se cumule
  - [ ] les dinos longs (Spino, Rex Cristal) restent dans leur enclos
  - [ ] la sauvegarde : quitte puis reviens, la progression est conservée
  - [ ] les sons (chemins `rbxasset://` non confirmés) ; remplace-les dans `Config.Sounds` si besoin
  - [ ] l'affichage sur téléphone (menu latéral de 7 boutons)

## 1 bis. Modèles externes (boîte à outils)
Les 6 modèles sont chargés côté serveur par `InsertService:LoadAsset`, dans un pcall, avec délai de 12 s, nettoyés (tout Script, LocalScript, ModuleScript, RemoteEvent, BindableEvent et autre objet non prévu est supprimé), avec repli automatique sur les modèles actuels. Réglages : `Config.Assets` (`enabled = false` coupe tout le chargement).
- [ ] Vérifie dans la boîte à outils que chaque modèle est **public ou appartient au créateur de l'expérience** (sinon LoadAsset échoue et le repli s'applique) : 116741237427172 (plante en pot), 15078054751 (plante de fenêtre), 101176034116232 (Sakura), 1338860741 (table), 10683798442 et 71422282686175 (T-Rex).
- [ ] Vérifie que tu as le droit d'utiliser ces modèles (licence et auteur) avant de publier.
- [ ] Teste dans Studio : les modèles s'affichent à la bonne taille au musée (lobby, à l'ouest) et sur les parcelles (plantes près du site de fouille et du laboratoire) ; lis la Sortie pour les messages `[AssetService]` en cas d'échec.
- [ ] T-Rex du musée : désactivés par défaut. Mets `Config.Assets.museumTrex.enabled = true` si tu veux les afficher, puis regarde s'ils sont à ta convenance.
- [ ] Si un modèle est trop lourd, trop clair ou mal orienté, ajuste `targetHeights` dans `Config.Assets`.

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
