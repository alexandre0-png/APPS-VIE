# À faire par l'utilisateur (uniquement ce que seul l'utilisateur peut faire)

## 1. Tester dans Roblox Studio (indispensable, rien n'a pu être exécuté ici)
1. Ouvrir `build/CityRush.rbxlx` dans Studio (ou `rojo serve` avec `default.project.json`).
2. Home > Game Settings > Security : activer **Enable Studio Access to API Services** (sinon sauvegarde en mode temporaire).
3. Play (F5). Attendre la fin du chargement (~5-15 s, la ville est générée par script).
4. Vérifier dans l'Output : aucune erreur rouge. Me transmettre les erreurs éventuelles.
5. Points à regarder en priorité : voiture qui avance/tourne (conduite arcade), police qui poursuit (3 étoiles : casse de la banque), missions, menus G/B/P/M/J (journal d'enquête : énigmes puis saisie du code 7391), mobile (émulateur de téléphone).

### Réglages visuels à ajuster après le test
Tout est dans `Config.Visual` (`src/ReplicatedStorage/Shared/Config.lua`) : `Enabled`, `Details`, `Quality` (auto/low/medium/high), `LampLights`, `SirenGlow`, `CrashSparks`, `SpeedTrail`, `CameraShake`, `Grade`.
Si les performances mobiles sont insuffisantes : `Quality = "low"`, `Details = false`, ou `Enabled = false`.

### Animations à valider visuellement
`Config.Animations` (activer/couper chaque animation) : roulis et suspension de caméra, dérapage (fumée), démarrage, porte conducteur, éclair de phares au klaxon (H), menottes à l'arrestation, ouverture des menus, pop des gains, arrivée des missions, journal (chiffres + texte tapé).
Les animations sont locales (visibles par le joueur concerné). Si la caméra paraît trop penchée : réduire `MaxLeanDegrees`.

### Cinématiques à valider visuellement
3 moments clés seulement (`Config.Cinematics`, 20 à 40 s) : intro de la ville (contexte, principe, but), mini tutoriel au premier lancement (conduire, missions, police), première poursuite de police. Le reste (énigmes, braquage...) reste en gameplay.
Skippables (bouton, Espace, Entrée, B manette), jouées une seule fois par joueur, jamais bloquantes (caméra toujours restaurée).
À vérifier : cadrages (positions en studs dans `Sequences.*.shots`), lisibilité des légendes sur mobile. Pour les revoir : `PlayOnce = false` ou couper une séquence avec `enabled = false`.

### Modèles Roblox externes (Config.Assets)
22 identifiants fournis (10 voitures, 2 véhicules de police, 1 épave, 9 objets de décor). Ils sont chargés côté serveur (InsertService:LoadAsset, pcall, délai 10 s), nettoyés (aucun script / remote / bindable / son / siège conservé) et servent d'apparence seulement : la conduite reste celle du jeu. Si un modèle est invalide ou introuvable, la voiture intégrée reste en place. `Config.Assets.Enabled = false` coupe tout chargement.
À vérifier dans Studio :
- [ ] Les modèles se chargent (Output : lignes `[AssetService] modèle ... ignoré` en cas d'échec). `LoadAsset` exige que le modèle soit accessible à l'expérience (public / appartenant au créateur) ; un modèle retiré ou refusé sera simplement ignoré.
- [ ] Sens des voitures : si un modèle regarde vers l'arrière, mettre `Config.Assets.Yaw[<id>] = 180` (le jeu aligne seulement l'axe long du modèle sur l'avant/arrière).
- [ ] Échelle (longueur du châssis + 1 stud) et hauteur au sol, alignement des roues sur les colliders.
- [ ] Épaves (zone industrielle nord-ouest), club billard (côté est de la place centrale) et mobilier.
- [ ] Les couleurs du garage ne s'appliquent pas aux voitures habillées (le modèle garde ses couleurs).
- [ ] Marques : plusieurs modèles reproduisent des constructeurs réels. Les noms affichés dans le jeu restent génériques ; à toi de juger si l'usage des modèles est conforme aux règles de Roblox pour ta publication.
- Le modèle « voiture qui prend feu » n'est utilisé qu'en épave visuelle (ancrée, sans siège), jamais en véhicule jouable. Aucun modèle de ski ou de neige n'est utilisé.

## 2. Publication (Open Cloud / Creator Hub)
- [ ] Créer une expérience vide dans le Creator Hub -> noter **universeId** et **placeId**.
- [ ] Fournir une clé API Open Cloud (jamais dans le dépôt) : variable `ROBLOX_API_KEY`, permissions `universe-places:write`, `universe.developer-product:write`, `universe.game-pass:write`.
- [ ] Lancer : `python3 tools/publish.py --universe <U> --place <P>` (publie le lieu depuis `src/`).
- [ ] Vérification d'identité / âge (obligatoire pour publier et vendre) : à faire sur le site Roblox.
- [ ] Questionnaire de classification par âge (réponses conseillées dans `publication/description.md`).

## 3. Achats intégrés (noms et prix dans `publication/monetization.md`)
- [ ] 3 Developer Products : Sac de billets 49 R$, Mallette 249 R$, Coffre-fort 999 R$
- [ ] 2 Game Passes : VIP CITY RUSH 399 R$, Nitro Infini+ 149 R$
- [ ] Coller les IDs dans `src/ReplicatedStorage/Shared/MonetizationIds.lua` (ou `tools/publish.py --universe <U> --setup-monetization`, best effort, formats d'API non vérifiés).

## 4. Images (non gérées par Open Cloud)
- [ ] Téléverser l'icône `publication/images/icon_512.png` (Creator Hub > Basic Settings > Icon)
- [ ] Téléverser les vignettes `publication/images/thumbnail_*_1920x1080.png` (Media)
- [ ] Recommandé : remplacer par de vraies captures prises dans Studio après le test.

## 5. Facultatif
- [ ] Sons moteur / klaxon / sirène : aucun son intégré Roblox ne convient, ils sont donc désactivés (`Config.Sounds.*` vides). Téléverser des audios libres de droits dans le Creator Hub, coller leurs `rbxassetid://...` dans `Config.Sounds` : `SoundController` fait le reste (pitch moteur lié à la vitesse, klaxon touche H).
