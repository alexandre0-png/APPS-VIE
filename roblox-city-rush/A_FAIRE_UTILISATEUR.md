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
