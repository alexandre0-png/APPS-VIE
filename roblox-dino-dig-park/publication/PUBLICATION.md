# Publier Dino Dig Park sur Roblox (tout se fait dans Roblox, sans API externe)

Je ne peux pas me connecter à ton compte Roblox : la publication, la création des passes et l'envoi des images se font donc par toi, dans Studio et Creator Hub. Tout le contenu est prêt à copier dans ce dossier. Temps estimé : 30 à 40 minutes.

## 1. Construire le fichier de jeu
Option A (recommandée) : Rojo 7.4+
1. Installe Rojo (rojo.space) et son plugin Studio.
2. Dans ce dossier : `rojo build -o DinoDigPark.rbxlx`, puis ouvre le fichier dans Roblox Studio.

Option B (sans Rojo) : dans un place vide, crée à la main `ReplicatedStorage > Shared` (dossier), `ServerScriptService > Server` (dossier), `StarterPlayer > StarterPlayerScripts > Client` (dossier). Colle chaque fichier de `src/shared`, `src/server`, `src/client` en ModuleScript, sauf `Main.server` (Script, dans Server) et `Main.client` (LocalScript, dans Client). Le nom du script est le nom du fichier sans `.luau`.

## 2. Réglages du jeu (Home > Game Settings)
- Basic Info : nom `Dino Dig Park`, description (section 4), genre Tycoon.
- Security : active « Enable Studio Access to API Services » (sans cela, la sauvegarde ne fonctionne pas dans Studio) et « Allow HTTP Requests » inutile.
- Players : Maximum Players = 10 (il y a 10 parcelles ; le 11e joueur serait expulsé avec un message).
- Avatar : R15 ou R6, les deux fonctionnent.
- Workspace : laisse StreamingEnabled désactivé.
- Publie : File > Publish to Roblox.

## 3. Monétisation (Creator Hub > ton expérience > Monetization)
Crée les 3 passes (Passes > Create a Pass) et les 2 produits (Developer Products), avec les images de `images/` :

| Élément | Nom | Prix conseillé | Image | Clé dans Config.luau |
|---|---|---|---|---|
| Pass | Revenus x2 | 399 R$ | pass_revenus_x2.png | `Config.Passes.doubleCash.id` |
| Pass | Fouille automatique | 249 R$ | pass_fouille_auto.png | `Config.Passes.autoDig.id` |
| Pass | Éclosion rapide | 299 R$ | pass_eclosion_rapide.png | `Config.Passes.fastHatch.id` |
| Produit | Pack de fossiles | 49 R$ | produit_pack_fossiles.png | `Config.Products.fossilPack.id` |
| Produit | Pack de pièces | 99 R$ | produit_pack_pieces.png | `Config.Products.cashPack.id` |

Copie chaque ID numérique dans `src/shared/Config.luau` (champ `id = 0`), puis republie. Tant qu'un ID vaut 0, l'article est caché dans le jeu et le bouton Boutique n'apparaît pas. Les achats sont validés côté serveur (reçus idempotents, sauvegarde avant confirmation).

## 4. Page du jeu
Titre : **Dino Dig Park**

Description française :
> 🦖 Creuse des fossiles, fais éclore des œufs et bâtis le plus beau parc de dinosaures !
> ⛏ Fouille le sol, trouve des trouvailles rares
> 🥚 4 types d'œufs : Fossile, Jungle, Volcan, Cosmique
> 🦕 18 dinos à collectionner (Commun → Mythique), versions dorées et un dino secret
> 🏗 6 enclos, café, boutique, hôtel, grande roue, hélipad
> 🌟 Renaissance pour des bonus permanents, quêtes et cadeau quotidien
> ☄ Pluies de météores toutes les 10 minutes
> Cherche les 5 os dorés cachés pour débloquer Aurore !

English description:
> Dig up fossils, hatch eggs and build the ultimate dinosaur park! 18 dinos to collect (Common to Mythic, plus golden variants and a secret one), 6 themed pens, shops, a Ferris wheel, rebirths, daily quests and meteor showers.

Genre : Tycoon. Appareils : ordinateur, téléphone, tablette, console. Questionnaire de maturité : aucune violence, aucun contenu sensible (réponds « non » partout), ce qui donne généralement « All Ages ». Tags/mots-clés : tycoon, dinosaures, dino, fouille, œufs, collection, parc.

## 5. Images (Creator Hub > Basic Info)
- Icône : `images/icone_512.png` (512×512)
- Miniatures (1920×1080, jusqu'à 10) : `miniature_1_heros.png`, `miniature_2_raretes.png`, `miniature_3_fonctions.png`
Régénérer ou modifier : `python3 publication/make_images.py` (utilise les vraies formes de dinos du jeu).

## 6. Lancement
1. Teste dans Studio (Test > Clients and Servers, 2 joueurs) et vérifie que la progression est conservée après avoir quitté.
2. Remplace au besoin les sons dans `Config.Sounds` (IDs `rbxasset://` natifs, non vérifiés dans le moteur).
3. Creator Hub > Experience > Settings > Privacy : passe en Public.
4. Pour la visibilité : active les Sponsored Ads (Robux) depuis Creator Hub, la découverte vient surtout de la rétention des 30 premières minutes.
