# Publication sur Roblox — tout se fait dans Roblox, sans API

Rien ne peut être publié sans ton compte Roblox : la mise en ligne se fait donc depuis ton Studio (≈ 20 min).
Tout le contenu à copier-coller et toutes les images sont prêts.

## 1. Publier le jeu
1. Ouvrir `dist/FestinDuTRex.rbxlx` dans Roblox Studio.
2. **Game Settings → Security → Enable Studio Access to API Services** (sauvegarde des données) → Save.
3. Lancer **Play** une fois, lire la fenêtre *Output* (aucune erreur rouge attendue). Corriger sinon.
4. **File → Publish to Roblox** → *Create new game* → nom ci-dessous → Create.

## 2. Page du jeu (Creator Dashboard → ton jeu → Configure / Settings → Basic Info)
**Nom (≤ 50)** : `🦖 Festin du T-Rex [Nouveau]`

**Description (≤ 1000)** :
```
🦖 Un T-Rex géant a FAIM… et il compte sur toi !

Prends de la nourriture aux stands, vise sa bouche et lance ! Plus tu enchaînes, plus ton COMBO grimpe. Remplis sa jauge avec les autres joueurs pour déclencher un FESTIN : tout le monde gagne des pièces et le dino GRANDIT (Bébé Rex → Titan Rex).

🍎 6 nourritures à débloquer, du fruit à la dinde dorée
🌊 Marée de sauce : grimpe sur les tables pour survivre !
🍗 Pluie gourmande et 🔥 Frénésie (pièces x2)
🥚 Œufs et 11 compagnons, du commun au MYTHIQUE
📜 Quêtes du jour et récompenses de connexion
🍴 5 fourchettes d'or cachées sur la carte
✨ Évolution : repars de zéro avec des gains permanents
🏆 Classement mondial des plus gros nourrisseurs

Joue sur téléphone, tablette, PC ou console.
Mets en favori ⭐ et invite tes amis : plus on est nombreux, plus le festin est rapide !
```
**Genre** : *Fun* (ou *Comedy*) · **Appareils** : Ordinateur, Téléphone, Tablette, Console · **Max joueurs** : 20 (serveur) · **Accès** : *Public* quand tu es prêt.

## 3. Images
| Où | Fichier | Taille |
|---|---|---|
| Icône du jeu | `dist/store/icon.png` | 512×512 |
| Miniatures (Media) | `dist/store/thumb1.png`, `thumb2.png`, `thumb3.png` | 1920×1080 |
| Game Pass VIP | `dist/store/pass_vip.png` | 512×512 |
| Game Pass Nid agrandi | `dist/store/pass_nest.png` | 512×512 |
| Game Pass Super visée | `dist/store/pass_aim.png` | 512×512 |
| Produit Sac de pièces | `dist/store/prod_coins_s.png` | 512×512 |
| Produit Coffre de pièces | `dist/store/prod_coins_l.png` | 512×512 |
| Produit Pack d'œufs | `dist/store/prod_eggs.png` | 512×512 |

⚠️ Ces visuels sont des **illustrations** dans le style du jeu. Roblox demande des miniatures représentatives du jeu : une fois en Studio, ajoute 1 à 2 vraies captures (Studio → View → *Screenshot* ou touche F12 en jeu) et garde les illustrations en complément. Régénérer les images : `node tools/store_assets/render.js`.

## 4. Achats intégrés (Creator Dashboard → ton jeu → Monetization)
**Game Passes** (Passes → Create a Pass), image + nom + description + prix :
| Clé dans `Config.Monetization.Passes` | Nom | Description | Prix conseillé |
|---|---|---|---|
| `vip` | VIP Gourmet | +50% de pièces, pour toujours | 399 R$ |
| `nest` | Nid agrandi | +1 emplacement de compagnon | 199 R$ |
| `aim` | Super visée | Assistance de visée x2 | 149 R$ |

**Produits développeur** (Developer Products → Create) :
| Clé dans `Config.Monetization.Products` | Nom | Prix conseillé |
|---|---|---|
| `coins_s` | Sac de pièces (5 000) | 49 R$ |
| `coins_l` | Coffre de pièces (75 000) | 449 R$ |
| `eggs` | Pack de 5 œufs | 99 R$ |

Pour chacun : copier l'**ID** affiché, le coller dans `ReplicatedStorage → Shared → Config` (champ `Id = 0`), puis republier (File → Publish to Roblox).
Tant que `Id = 0`, l'onglet 💎 Robux affiche « Bientôt ». Le prix affiché en jeu est indicatif : Roblox applique le prix réel du Dashboard.

Côté code (déjà fait) : `MonetizationService` vérifie la propriété des passes à chaque connexion, accorde les produits de façon idempotente (`ProcessReceipt`, un reçu n'est jamais crédité deux fois, annulation si la sauvegarde échoue).

## 5. Avant de passer en public
- Dashboard → **Settings → Maturity & Compliance** : remplir le questionnaire de classification (contenu : aucune violence, pas de langage, achats intégrés oui).
- Tester avec 2 comptes (ou *Test → Local Server*, 2 joueurs) : lancers, festin, marée de sauce, achat d'un œuf, sauvegarde après reconnexion.
- Tester un achat de Game Pass avec un compte de test.
- Passer le jeu en **Public**, puis partager le lien.

## 6. Après lancement (fidélisation)
Surveiller Analytics (rétention J1/J7, durée de session) ; ajuster les prix et durées dans `Config.luau`. Idées de mises à jour : nouveau stade du dino, œuf saisonnier, nouvel événement.
