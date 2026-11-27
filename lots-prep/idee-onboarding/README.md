# Jeu 2 (Chipe-Œufs) : idée 1, onboarding « premières 5 minutes » (lot 17, préparation)

Préparé hors de la branche de jeu de la session Jeu 2, sur la base du commit `fa4e42b` (lot 14 intégré). Rien n'est branché : modules purs, tests et patches à appliquer.
Spec : `obsidian-studio/Jeux/IDEES_CHIPE_OEUFS.md`, idée 1 (idée 2 dans la numérotation du fichier : « Premières 5 minutes guidées »).

## Contenu

| Fichier | Rôle |
|---|---|
| `roblox/src/ReplicatedStorage/Onboarding.lua` | Module PUR : séquence de 5 étapes, états, transitions, textes, garde-fous, migration idempotente |
| `roblox/tests/onboarding.luau` | 62 assertions : partie pure puis intégration dans le vrai `Main.server.lua` + `Data.lua` (runtime factice) |
| `roblox/tests/run_onboarding.py` | Lanceur autonome (lupa), même principe que `run_lot16.py` |
| `patches/01-config.patch` | `Config.ONBOARDING` (+1 ligne de configuration) |
| `patches/02-data.patch` | Champ de profil `onb` : défaut + migration (SANS changement de version, v13 reste v13) |
| `patches/03-main.patch` | Branchement serveur : snapshot, tick (revenu + faits), arène, rebirth, reprise, action `onbSkip` |
| `patches/04-client.patch` | Carte d'objectif : lit `state.onb`, « Passer » prévient le serveur |
| `patches/05-tests-run.patch` | Ajoute `onboarding` à `run.luau` (suite lot 16) |

## La séquence (fixe, une seule action attendue par étape, ignorable)

| # | Étape | Validée par (décidé par le SERVEUR) |
|---|---|---|
| 1 | Œuf offert | Le joueur est dans sa base (`inPlot`, position lue côté serveur), après 3 s d'affichage |
| 2 | Éclosion commentée | `d.hatched >= 1` (lu dans le profil) |
| 3 | Premier revenu | 10 pièces de revenu réellement versées par le tick (joueur actif ; `earnGoal`) |
| 4 | Première maison | `s.baseLevel >= 2` (`houseLevel`) |
| 5 | Premier pet à l'arène | `actions.towerStart` a ACCEPTÉ un combat (équipe non vide, étage valide, quota) |

Garde-fous du module : une étape n'accepte que son type d'événement (`tick` pour 1, 2, 4 ; `earn` pour 3 ; `arena` pour 5), avec des valeurs numériques saines (NaN, infini, négatif, texte refusés) ; jamais de saut d'étape ; 3 s d'affichage minimum par étape (pas d'enchaînement instantané) ; après 45 s sans progrès le texte passe en « aide » (jamais de validation automatique) ; le client n'envoie aucun fait, seul `onbSkip` existe et ne fait que terminer le tutoriel ; terminé ou passé = définitif (le rebirth reporte `onb`, la reconnexion relit le DataStore).

## Champ de profil `onb` et migration

`onb = { v = 1, step = 1..5 (6 = terminé), at = début de l'étape, prog = pièces comptées (étape 3), skip = bool }`.
`Onboarding.migrate(saved)` est idempotente (testée sur 12 profils) et ne touche à rien d'autre que `onb` :
- `onb` présent : simplement assaini (champs hors bornes ou corrompus = valeur neuve du champ), JAMAIS réinitialisé ;
- profil v13 sans `onb` avec au moins une éclosion, ou 120 s de jeu ou plus : marqué terminé (`step = 6`), aucun tutoriel pour un joueur existant ;
- profil sans `onb`, 0 éclosion et moins de 120 s de jeu : reçoit la séquence ;
- `Config.ONBOARDING.enabled = false` coupe tout (vue `nil`, événements ignorés, profil intact).

## Brancher

Depuis la racine de la branche de jeu (là où se trouve `roblox/`) :

```
cp -r lots-prep/idee-onboarding/roblox/* roblox/
for p in lots-prep/idee-onboarding/patches/*.patch; do patch -p1 < "$p"; done
```

Chaque patch a été testé avec `patch -p1 --dry-run` sur une copie neuve de `fa4e42b` (5 fichiers, aucun rejet, aucun décalage). Si la branche de jeu a avancé, les hunks sont petits et ont chacun une ligne d'ancrage unique ; en cas de rejet, reposer à la main les lignes suivantes.

Lignes changées (numéros de `fa4e42b`) :
- `Config.lua` (avant `Config.SEASON = {`, l. 2717) : `Config.ONBOARDING = { enabled = true, stepSeconds = 45, minDwell = 3, earnGoal = 10, houseLevel = 2, legacyPlayedSeconds = 120 }`.
- `Data.lua` : `require` d'`Onboarding` (après `Ranked`, l. 18) ; dans `Data.default`, après `SeasonMod.migrate(d, os.time())` (l. 238) : `d.onb = OnbMod.default()` ; dans `merge`, après `SeasonMod.migrate(d, os.time())` (l. 488) : `d.onb = OnbMod.migrate(saved)`.
- `Main.server.lua` : `Onb = require(...)` dans la table `L15` (aucune nouvelle variable locale, limite de 200) ; `onb = L15.Onb.view(...)` dans `snapshot` ; dans le tick par joueur, `L15.onb(s, "earn", inc * dt)` dans le bloc `if active` puis `L15.onbTick(s, dt)` ; `L15.onb(s, "arena")` dans `actions.towerStart` juste après `b.fights += 1` ; `fresh.onb = d.onb` dans `actions.rebirth` ; `L15.Onb.resume(...)` dans `L16.join` ; nouvelles fonctions `L15.onb`, `L15.onbTick`, `actions.onbSkip` avant `actions.sync`.
- `Client.client.lua` : `onboardStep()` renvoie la vue serveur quand `state.onb` existe ; le bouton « Passer » envoie `RAction:FireServer("onbSkip")`.
- `run.luau` : `"onboarding"` ajouté à la liste de la suite lot 16.

## Résultats

Voir la section « Résultats » ci-dessous (mise à jour avec les exécutions réelles).

RESULTATS_PLACEHOLDER

## Écarts avec la spec

1. **Étape 1 « œuf offert »** : l'œuf de départ est déjà dans le profil (slot 1) ; l'action réelle validée est « être dans sa base » (position serveur), pas un clic sur l'œuf (l'éclosion est automatique à 12 s).
2. **« ≤ 45 s par étape »** est une durée visée, pas un minuteur qui valide : après 45 s le texte d'aide s'affiche, mais l'étape n'avance QUE par l'action. Les étapes 4 (maison niveau 2 = 18 points de base, soit plusieurs éclosions de rareté 1) et 5 (équipe + combat) dépendent du rythme du joueur : à mesurer en jeu.
3. **Ancien guidage conservé** : `Config.onboarding` / `Config.TUTORIAL` (client) ne sont pas supprimés. Pendant la séquence serveur, elle est prioritaire sur la carte « Étape x/4 » ; une fois finie ou passée, l'ancien guidage reprend comme avant pour un joueur qui n'a rien chipé (ex. « Chipe un œuf dans l'enclos »). Pour ne garder que le nouveau, retirer l'ancienne branche de `onboardStep()`.
4. **Pas de télémétrie** : les noms de `Telemetry.ONBOARDING` / `METRICS` sont fermés ; ajouter les 5 étapes demanderait de toucher `Telemetry.lua` (hors des 4 fichiers demandés). Piste : un événement `onboarding` par étape franchie, pour mesurer « éclosion 2 » (+20 % visé).
5. **Pas de récompense de fin** (non demandée). Piste : un œuf du sac ou quelques pièces à la fin de l'étape 5.
6. **Boutique et offres** : aucune offre n'est déclenchée pendant le tutoriel (rien dans le patch ne touche Shop/Offers).

## Analysé uniquement (non exécuté)

- Le client (`Client.client.lua`) : relu, jamais exécuté (pas de runtime d'UI) ; `selene` ne peut pas collecter la bibliothèque Roblox ici (API dump inaccessible), donc pas d'analyse statique outillée.
- Compatibilité mobile / manette : la carte d'objectif et le bouton « Passer » existent déjà (inchangés, mêmes composants) ; rien de spécifique n'est ajouté.
- `StreamingEnabled` : le fait « dans la base » est lu côté serveur (`inPlot` sur `HumanoidRootPart`), non affecté.

## À tester dans Studio

1. **Compte neuf** (ou profil supprimé) : rejoindre la partie. Attendu : carte jaune « Étape 1/5 · Voici ton œuf offert ! Reste près de lui. », flèche vers la base. S'éloigner de la base de 30+ studs : l'étape ne passe pas ; revenir : elle passe au bout de quelques secondes.
2. **Éclosion** (12 s) : la carte passe à « Étape 3/5 » (revenu) avec compteur x/10 ; rester actif (bouger) : en une dizaine de secondes elle passe à « Étape 4/5 » ; rester immobile longtemps : le texte d'aide « Bouge un peu » apparaît à 45 s.
3. **Maison** : acheter et poser des œufs jusqu'au niveau 2 (Chalet du Couvoir) : « Étape 5/5 ». Lancer l'Arène étage 1 SANS équipe : refus, étape inchangée. Composer une équipe puis lancer : la carte disparaît et « 🎉 Tutoriel terminé » s'affiche.
4. **Passer** : sur un autre compte neuf, appuyer sur « Passer › » à l'étape 1 : la carte disparaît ; quitter et revenir : elle ne revient pas.
5. **Renaissance** après tutoriel terminé : il ne repart pas. **Profil existant** (compte avec des éclosions) : aucune carte du nouveau tutoriel, l'ancien guidage éventuel se comporte comme avant.
6. **Mobile** : la carte reste lisible (texte long ≤ 90 caractères), « Passer » appuyable au pouce.
