---
type: pieges
---
# Pièges rencontrés
1. **Script serveur qui meurt avant les Remotes** : un `require(script.Parent.Common...)` mal résolu (Shop.lua) empêchait tout le démarrage. Symptômes : client « Infinite yield possible on ReplicatedStorage:WaitForChild("Remotes") », joueur dans le ciel, chute et mort. Garde-fou : tests qui résolvent chaque `require` dans l'arbre Rojo réel.
2. **Lieu de départ non modifiable** depuis le tableau de bord de l'utilisateur : on a inversé les rôles des lieux (le lieu de départ devient le hub, le nouveau lieu devient la partie).
3. **Studio ne téléporte pas entre lieux** : tester depuis roblox.com (bouton Jouer), pas depuis Studio.
4. **Studio ouvert ou Création en équipe** : provoque l'erreur 409 et peut écraser une publication (le hub contenait le script de la partie après une fermeture de Studio).
5. `StreamingEnabled=false` dans les deux `.project.json` (hub et partie).
6. **Lune** : un test qui lit des fichiers depuis une coroutine factice reste figé sous Lune mais passe sous lupa. Toujours lancer la suite sous Lune avec un délai.
7. **stylua** doit être compilé avec `--features luau` ; il plante sur l'opérateur `//` (Jeu 3), bug de l'outil.
8. Les sessions de jeu ne peuvent pas toujours exécuter rojo, stylua ou Lune (autorisation refusée) : la gestion refait les vérifications.
9. Les binaires téléchargés depuis GitHub sont refusés par le classificateur : ne pas en demander aux sessions.
10. Modèles catalogue refusés par `LoadAsset` (« Requester does not have permission ») : repli procédural. Œufs concernés : 2937230482, 147144059, 2937218888.
11. Avant d'envoyer un message à une session, vérifier son ID (un message a été envoyé à la mauvaise session une fois).
12. Les IDs « 10776… » fournis par l'utilisateur sont des IDs d'univers.
