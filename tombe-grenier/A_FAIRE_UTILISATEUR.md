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
6. **Images et textures** : vérifier que les textures fournies s'affichent correctement dans Studio.
7. **Vérification d'identité** : si Roblox la demande pour publier ou pour les achats, c'est à toi de la faire.
8. **Formatage stylua** : non fait (téléchargement refusé dans cet environnement). À lancer toi-même si tu veux : `stylua src tools`.
