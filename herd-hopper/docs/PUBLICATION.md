# Publier Saute-Troupeau sur Roblox

Tout se fait dans Roblox Studio et sur le Creator Dashboard (create.roblox.com), sans API.
Je ne peux pas me connecter à ton compte depuis mon environnement : ces étapes sont les seules qui restent manuelles.
Durée estimée : 30 à 45 minutes, achats compris.

Fichiers prêts à l'emploi :
- `build/SauteTroupeau.rbxlx` : le jeu complet (à ouvrir dans Studio)
- `marketing/` : icône, 3 vignettes 1920×1080, 3 icônes de pass, 3 icônes de paquets de pièces
- ce guide : textes à copier-coller

## 1. Premier test dans Studio (obligatoire)

Le jeu n'a pas encore tourné dans Roblox (voir README, section « Vérifications »). Fais ce passage avant de publier.

1. Studio > Fichier > Ouvrir depuis le fichier > `build/SauteTroupeau.rbxlx`.
2. Accueil > Paramètres du jeu > Sécurité : active **Autoriser l'accès de Studio aux services API** (sinon la sauvegarde est coupée en test, un message le signale en jeu).
3. Paramètres du jeu > Avatar : **R15**.
4. Onglet Test > Clients et serveurs : 2 joueurs, puis Démarrer. La carte met quelques secondes à se construire.
5. Ce qu'il faut voir : le compte à rebours, ta monture sous toi, ESPACE qui te propulse, le lasso auto en maintenant ESPACE en l'air, le mur de lave derrière, les résultats, la boutique.
6. Si un comportement paraît faux, regarde la fenêtre Sortie. Les réglages de sensation sont dans `ReplicatedStorage > Shared > Config`.

Points à surveiller en premier (non vérifiables sans Studio) : le cavalier suit bien sa bête, la caméra reste derrière, le tactile (émulateur de téléphone), la sauvegarde.

## 2. Publier

Fichier > Publier sur Roblox sous... > Créer un nouveau jeu :
- Nom : **Saute-Troupeau**
- Description : voir section 5
- Genre : Action (ou Aventure)
- Appareils : ordinateur, téléphone, tablette, console

## 3. Page du jeu (Creator Dashboard)

Creator Dashboard > Expériences > ton jeu > Configurer.

| Réglage | Valeur |
|---|---|
| Icône | `marketing/icone-experience-512.png` |
| Vignettes | `marketing/vignette-1…`, `vignette-2…`, `vignette-3…` (dans cet ordre) |
| Joueurs max par serveur | 12 à 16 (le jeu gère jusqu'à environ 20) |
| Questionnaire de classification | À remplir honnêtement : pas de violence réaliste, pas de langage, pas de contenu sombre, achats optionnels. C'est toi qui réponds |
| Confidentialité | Reste en Privé tant que les tests ne sont pas finis, puis Public |

Le questionnaire de classification est obligatoire avant de passer en public.

## 4. Achats intégrés

Le code est prêt (`MonetizationService`) : il gère les pass, les paquets de pièces, les reçus (sans doublon) et refuse tout achat si la sauvegarde est indisponible. Il reste à créer les objets et à copier leurs identifiants.

Creator Dashboard > ton jeu > Monétisation (ou « Objets associés »).

**Pass (Passes)** : crée 3 pass avec l'icône et le prix suggéré.

| Pass | Icône | Prix suggéré | Description à copier |
|---|---|---|---|
| Pièces x2 | `pass-pieces-x2-512.png` | 199 R$ | Double toutes les pièces gagnées en course, pour toujours. |
| Corde longue +8 m | `pass-corde-longue-512.png` | 149 R$ | Portée du lasso +8 m en permanence. |
| VIP | `pass-vip-512.png` | 99 R$ | Cornes dorées exclusives pour ton cavalier. |

**Produits développeur (Developer Products)** : crée 3 produits.

| Produit | Icône | Prix suggéré |
|---|---|---|
| Sac de 500 pièces | `produit-500-pieces-512.png` | 49 R$ |
| Coffre de 1 500 pièces | `produit-1500-pieces-512.png` | 129 R$ |
| Trésor de 5 000 pièces | `produit-5000-pieces-512.png` | 349 R$ |

Les prix sont des suggestions : choisis ceux que tu veux. Le jeu lit le prix réel sur Roblox et l'affiche dans l'onglet ROBUX.

**Copier les identifiants** : dans Studio, ouvre `ReplicatedStorage > Shared > Config` et remplis les `id = 0` de `Config.Monetization` (3 pass dans l'ordre double, rope, vip ; 3 produits dans l'ordre coins_s, coins_m, coins_l). Publie à nouveau (Fichier > Publier sur Roblox). Tant qu'un id vaut 0, l'objet affiche « BIENTÔT ».

Test : lance un test dans Studio, ouvre le bouton ROBUX, achète un paquet. Vérifie que les pièces arrivent, qu'un second lancement ne les recrédite pas, et que le pass « Pièces x2 » double bien les gains de la manche suivante. Les achats faits depuis Studio ne doivent pas débiter de vrais Robux ; confirme-le avec un petit achat test avant d'ouvrir au public.

## 5. Textes de la page du jeu

**Description (français)**

> Un troupeau géant fonce vers un volcan. Saute de bête en bête au lasso, dompte-les toutes et reste devant le mur de lave !
>
> 🐗 Bondis en l'air, maintiens pour lasser automatiquement la bête dorée à portée
> 🔥 Un mur de lave accélère derrière toi : ralentis et tu es éliminé
> ⭐ Enchaîne les lassos pour faire monter ton COMBO
> 🦣 7 espèces à dompter, en versions Normale, Cristal et Dorée
> 🌋 4 biomes : savane, désert, forêt géante, volcan
> 🏆 Manches de 2 minutes, classement en direct, classement mondial
> 🎩 Chapeaux, cordes de lasso, améliorations, quêtes et cadeau du jour
>
> Rejoins une partie, une manche dure moins de 2 minutes !

**Description (anglais)**

> A giant herd stampedes toward a volcano. Lasso your way from beast to beast, tame them all and stay ahead of the lava wall!
>
> - Jump, then hold to auto-lasso the nearest beast
> - A lava wall speeds up behind you: fall behind and you're out
> - Chain lassos to build your COMBO
> - 7 species to tame, in Normal, Crystal and Golden versions
> - 4 biomes: savanna, desert, giant forest, volcano
> - 2-minute rounds, live and global leaderboards
> - Hats, lasso colors, upgrades, daily quests and daily gift

**Mots-clés suggérés** : lasso, troupeau, course, rodéo, animaux, dompter, multijoueur, manches courtes, lave, combo.

## 6. Mise en ligne

1. Repasse le jeu en Public (Creator Dashboard > Paramètres de l'expérience > Confidentialité).
2. Premier jour : surveille la fenêtre Développeur de la console Roblox (F9 en jeu) pour les erreurs.
3. Mises à jour : modifie dans Studio, puis Fichier > Publier sur Roblox. Les serveurs en cours se mettent à jour au redémarrage.

## Remarques

- Les images de `marketing/` sont des créations originales à partir des blocs du jeu. Régénérables avec `node tools/marketing/make.js` (Playwright requis).
- Les sons utilisent les fichiers intégrés au client Roblox. Pour une vraie ambiance, ajoute ta musique et tes bruitages (`Sfx.luau`).
- Roblox garde une commission sur les ventes, et le retrait d'argent réel demande de remplir les conditions du programme d'échange de développeur. Consulte les règles actuelles sur le site Roblox.
