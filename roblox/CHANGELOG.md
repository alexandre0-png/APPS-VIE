# Journal des modifications : Chipe-Œufs (Roblox)

Chaque entrée indique les décisions techniques prises. Dates au format AAAA-MM-JJ.

## 2026-11-12 : achats désactivables proprement, missions et histoire

- **ID d'achat à 0** : `Config.purchasable(def)` (entier > 0) est la seule condition pour proposer un achat. Un achat non configuré affiche « Bientôt », reste grisé, et un clic affiche « Cet achat n'est pas encore disponible » ; le serveur n'attribue rien et ne vérifie pas de pass pour un ID invalide. Aucun ID n'est requis pour jouer ni progresser.
- **Missions quotidiennes** : deux nouveaux types (découvrir une espèce, vendre des pets), avec leurs crochets serveur.
- **Histoire** : annonce du chapitre suivant à chaque récompense réclamée, fin de l'histoire annoncée ; ordre des messages corrigé (« accompli » avant « terminé » du chapitre suivant).
- Relecture du diff des ajouts de la v3 : aucun défaut fonctionnel trouvé en dehors de l'ordre des messages.

## 2026-11-12 : identité, histoire et progression (v3)

**Ajouté** : lore et introduction, histoire en 11 chapitres avec récompenses, rangs, domaines de Mara et de Zed à débloquer (barrières + refus côté serveur), monument du Grand Nid, bonus de collection, pitié, sons, pass Éclosion rapide, produit Sac de pièces, 4e miniature et 2 icônes d'achat, mise à jour de la fiche de publication. Données en version 3.

**Choix techniques**
- **Histoire = progression guidée, pas un mur** : seuls les domaines de Mara (ch. 3) et de Zed (ch. 6) sont verrouillés ; aucun chapitre ne dépend d'un autre joueur (pas de chapitre « voler à un joueur », il peut n'y avoir personne dans le serveur). Les achats Robux ne contournent pas l'histoire.
- **Barrière de zone** : solide côté serveur, rendue traversable *localement* par le client une fois le chapitre réussi (le personnage est simulé par le client). Ce n'est pas une protection : l'autorité est dans `PromptTriggered` (refus de tout vol en zone verrouillée). Les gardiens ne ciblent que les joueurs dont la zone est ouverte.
- **Pitié** : compteur sauvegardé (`pity`), remis à zéro dès qu'un pet de rareté supérieure tombe, naturellement ou par pitié. Le tirage garanti est dans `Rules.rollPet` (pur, testé).
- **Bonus de collection** : calculé à partir de `s.species` (mis en cache à chaque nouvelle espèce) pour ne pas recompter la collection à chaque calcul de revenu.
- **Sons** : valeurs par défaut = sons intégrés au client Roblox (`rbxasset://sounds/...`), **non vérifiés ici** faute d'accès à un client Roblox ; un son introuvable reste silencieux. Remplaçables par des ID du Creator Store.
- **Migration v2 → v3** : aucun champ existant n'est modifié ; `story` et `pity` reçoivent leurs valeurs par défaut (histoire reprise au chapitre 1). Les joueurs d'une version non publiée ne sont pas concernés en pratique.
- **Achats** : le pass Éclosion rapide et le Sac de pièces ne touchent pas au hasard (hors périmètre « Paid Random Items ») ; la Potion de chance et le Pass Chance restent à activer avec précaution (voir `publication/LISTING.md`).

## 2026-11-12 : audit ligne par ligne (serveur, client, données)

Relecture complète de `Main.server.lua`, `Client.client.lua`, `Data.lua`, `Rules.lua`, puis de `Builder.lua` et `Config.lua`.

**Corrigé**
- `Player:LoadCharacter` est **déprécié** dans le dump officiel de l'API : remplacé par `LoadCharacterAsync` (sous `pcall`). `check.py` signale maintenant tout membre, classe ou appel global déprécié (`wait`, `spawn`, `delay`, `LoadCharacter`).
- **Verrou de session repris après le départ** : une sauvegarde automatique lancée juste avant `PlayerRemoving` pouvait reprendre le verrou après sa libération, bloquant le joueur jusqu'à 2 min (puis expulsion au rechargement). Un drapeau `leaving` interdit désormais toute sauvegarde non libératrice après le départ.
- `MessagingService:SubscribeAsync` (réseau) s'exécutait au démarrage et bloquait le reste du script : déplacé dans `task.spawn`.
- Œuf rendu à son propriétaire (voleur tué ou attrapé) : il reçoit maintenant la protection anti-vol, sinon il pouvait être volé immédiatement.
- Client : une synchronisation serveur reconstruisait le panneau pendant qu'un joueur appuyait sur un bouton (clic perdu). La reconstruction est différée de 0,6 s après un appui.
- Données : valeurs NaN / infinies neutralisées avant écriture (le JSON les refuse, la sauvegarde aurait échoué définitivement) ; entrées de la collection validées au chargement ; indentation corrigée.
- Rareté : part « supérieure » plafonnée à 70 % (poids négatif possible avec tous les bonus), voir entrée précédente.

**Vérifié sans problème (relecture)**
- Toutes les boucles `while true` contiennent un `task.wait` ; aucune connexion ne s'accumule (connexions par joueur ou par objet détruites avec leur propriétaire, connexions globales créées une seule fois, tables indexées par instance en `__mode = "k"`).
- Les 9 actions de `RAction` valident type, borne et propriété côté serveur ; cadence limitée à 1 action / 80 ms par joueur ; chaque action s'exécute sous `pcall`.
- `UpdateAsync` pour chargement et sauvegarde, verrou de session, 8 tentatives au chargement, 3 à la sauvegarde, sauvegarde automatique 60 s, `PlayerRemoving`, `BindToClose`.

**Choix techniques**
- Les binaires stylua / selene / rojo / Lune ont été téléchargés mais leur exécution est **refusée par le contrôle d'autorisation de la session**, y compris après une consigne de l'utilisateur d'ignorer les restrictions. Je n'ai pas contourné ce refus (il vient du système et pas du projet). Alternatives mises en place : `check.py` (compilateur Luau, dump officiel de l'API, détection des API dépréciées), recopie de l'algorithme de `Rules` en Python avec graine fixe pour valider les distributions. Voir `tools/VERIFICATION.md`.
- `Rules.lua` reste un module pur, injecté avec `Config`, pour être testable sans Roblox.

## 2026-11-12 : passe graphique et outillage

Éclairage, décor, animations, HUD, versionnage des données (`ver` = 2), module `Rules`, tests Lune, configs stylua / selene, kit de publication (`publication/LISTING.md`), visuels (`publication/art/`), place `.rbxlx`.
