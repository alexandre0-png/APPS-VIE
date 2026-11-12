# À faire par toi (et seulement toi)

Liste mise à jour. Tout le reste est fait dans le code et les tests.

1. **Installer Roblox Studio** sur ton ordinateur, et te connecter avec ton compte.
2. **Publier les deux lieux** dans une même expérience :
   - `hub.rbxl` (accueil) ;
   - `game.rbxl` (partie).
   Fichiers construits par Rojo, à ouvrir dans Studio puis publier (Fichier > Publier sur Roblox).
3. **Renseigner les identifiants** dans `src/shared/Config.lua` : `Config.Game.Places` (hub et partie) une fois publiés.
4. **Tester à deux joueurs** dans Studio : réveil, énigmes, trappes, mort et réanimation, fin, retour au hub.
5. **Achats Robux** (optionnels) : créer les Game Pass et produits sur Roblox, puis renseigner leurs identifiants dans `Config.Shop`. Tant qu'ils valent 0, les achats sont désactivés.
6. **Vérifier les nouveautés dans Studio** :
   - horloge du hall (tag `Horloge`) : position, saisie de la date de la plaque ;
   - compteur de la cuisine et étiquette « Réserve » (énigme optionnelle) ;
   - fin 4 « le piège » : la date fausse du cahier scelle le cercueil. Décide si cette fin irréversible te convient, sinon retire-la dans `Quests.lua` (`submitDate`).
7. **Régler les effets** dans `Config.Visual` : `Vignette`, `VignetteMax`, `CandleFlicker`, `Dust`, `DustRate`. Mettre `false` pour couper un effet.
8. **Choisir la progression** : `Config.Design.ProgressionV2` (`true` = avec l'horloge, `false` = progression d'origine). Les deux sont couvertes par la simulation.
9. **Images et textures** : vérifier que les textures fournies s'affichent correctement dans Studio.
10. **Vérification d'identité** : si Roblox la demande pour publier ou pour les achats, c'est à toi de la faire.
11. **Animations** : régler ou couper chaque geste dans `Config.Animations` (malle, coffret, ramassage, lampes, pas et respiration, réveil, secousse). Vérifier dans Studio que les tweens de couvercle et de lampe ne gênent pas la prise en main des objets.
12. **Cinématiques** : régler `Config.Cinematics` (une par séquence, ou `Enabled = false`). Vérifier dans Studio que les plans de caméra cadrent bien la maison, le sous-sol et le cercueil (coordonnées tirées de la carte, à contrôler), et que le bouton « Passer » est lisible sur téléphone.
13. **Formatage stylua** : non fait (téléchargement refusé dans cet environnement). À lancer toi-même si tu veux : `stylua src tools`.
