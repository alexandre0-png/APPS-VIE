# Chipe-Œufs : catalogue des animations, effets 3D et cinématiques

Aucune de ces animations n'a été vue en Studio : tout est testé en logique pure et en simulation (runtime factice). Les tailles des modèles d'effets sont supposées naturelles (cercle runique 12 studs de diamètre, ailes 10 de large, pilier 12 de haut). Chaque famille se coupe par un drapeau de `Config.Animations` ou `Config.Cinematics`.

## 1. Effets 3D : `VfxKit` (`ReplicatedStorage/Shared/VfxKit.lua`)

Les 13 modèles Blender d'effets (pièces blanches `Nom__FFFFFF`, matière Neon) sont chargés par le serveur après la carte (plafond de 30 Parts par modèle, matière Neon conservée), publiés dans `ReplicatedStorage.VfxTemplates`, clonés par le client, recolorés par code (couleur de rareté ou blanc), ancrés, sans collision. Transparence, échelle, rotation et hauteur sont animées par TweenService ; tout est nettoyé par Debris et protégé par pcall.

| Préréglage | Pièces (priorité) | Particules | Durée | Qualité mini |
|---|---|---|---|---|
| `aura_runique` | cercle_runique, halo | 24 | 1,9 s | Bas |
| `aura_ailes` | ailes (+ Highlight) | 18 | 2,4 s | Moyen |
| `onde_de_choc` | onde | 14 | 0,9 s | Bas |
| `pilier_revelation` | pilier_lumiere, rayons, cone_lumiere (+ faisceau) | 30 | 1,8 s | Bas |
| `bouclier` | bouclier (+ Highlight) | 0 | 1,4 s | Bas |
| `etincelles` | etincelles | 30 | 1,6 s | Bas |
| `spirale_montee` | spirale, etoile | 26 | 2,4 s | Moyen |
| `portail_torii` | torii, cristaux | 22 | 2,9 s | Moyen |

Courbes : Back, Elastic, Quint, Quad, Sine. Qualité (automatique : Bas sur tactile, Élevé sinon ; forçable par `Config.VFX.quality`) :

| Qualité | Effets simultanés | Particules par émetteur | Faisceau | Pièces par effet |
|---|---|---|---|---|
| Élevé | 8 | 120 | oui | 3 |
| Moyen | 5 | 70 | non | 2 |
| Bas (mobile) | 3 | 40 | non | 1 |

Effets joués à l'éclosion d'un pet (en plus de la révélation en interface, qui reste) : Commun : étincelles discrètes ; Rare : + onde ; Épique : aura runique + onde ; Légendaire : pilier, aura, ailes, onde ; Mythique : + spirale ; Cosmique : tout, avec torii ; œuf secret : pilier, spirale, torii, aura, onde, étincelles à ampleur double. Victoire du château : étincelles et onde autour du joueur. Le préréglage `bouclier` est disponible pour la protection des œufs (non déclenché pour l'instant).

## 2. Cinématiques : `CinematicKit` (`ReplicatedStorage/Shared/CinematicKit.lua`)

Un plan est une liste de prises : position, cible, champ de vision, durée, courbe, trajectoire (travelling, orbite, plongée, zoom dolly), tremblement, ralenti, texte, carton de titre. Garanties : 8 secondes réelles au maximum (durées réduites proportionnellement sinon), bandes noires, bouton « Passer » (clic, Entrée, manette B ; un simple tap dans le monde pour les éclosions, sans bloquer l'inventaire), caméra et champ de vision toujours restitués (fin, passage, erreur, abandon, départ, délai de sécurité), jamais deux cinématiques en même temps, **aucune si le joueur est en danger** (moins de 50 % de pv, coup depuis moins de 4 s, poursuite par un gardien, salle à pièges, mort) ; toute touche reçue interrompt une cinématique en cours.

| Plan | Déclencheur | Durée réelle | Contenu |
|---|---|---|---|
| `hub_survol` | première arrivée au hub (pas au retour d'une partie) | 5,0 s | fontaine puis portails |
| éclosion Commun / Rare | éclosion | aucune cinématique | effets 3D seuls |
| `eclosion_epique` | éclosion Épique | 1,6 s | zoom sur l'œuf, léger tremblement |
| `eclosion` (Légendaire) | éclosion | 5,3 s | orbite lente, zoom avec ralenti à la fissure, secousse, retrait |
| `eclosion` (Mythique, Cosmique) | éclosion | 7,5 s | idem, plus ample, tremblement fort |
| `secret` | œuf secret | 7,5 s | plongée, orbite avec ralenti, zoom, carton « SECRET » |
| `chateau_entree` | entrée du château | 4,8 s | panoramique puis zoom, « La herse se lève… » |
| `chateau_victoire` | coffre final ouvert | 5,5 s | zoom au ralenti sur le coffre, orbite, carton « Victoire ! » |
| alerte « ❗ » | gardien ou chevalier qui repère le joueur | 1,2 s | AUCUNE caméra : à-coup de champ de vision, léger tremblement, carton ❗ ; refusée sous 40 % de pv, juste après un coup, plus de 3 par session, 90 s de recharge |

Les éclosions : au plus une cinématique toutes les 20 s. Intro, tutoriel, première zone et premier pet rare (système existant `Cinema`) restent inchangés.

## 3. Animations d'interface

Existantes : bouton qui se rétrécit à l'appui, menus qui s'ouvrent en rebondissant, texte flottant « +pièces » au gain, pulsation du compteur, confettis, secousse de caméra, pets (respiration, bonds, capacités).
Ajoutées (`Config.Animations.uiFx` et `pulse`) : compteur de pièces qui défile vers sa valeur, balayage de brillance sur le bandeau de rareté (dès Épique), flash de vignette coloré par rareté (dès Légendaire et secret), pulsation légère de `ColorCorrection` et `Bloom` à l'éclosion d'un pet rare (désactivable séparément).

Écran de tirage « machine à sous » (`SlotFx`, réglages `Config.REVEAL.slot`) : avant chaque révélation, trois rouleaux (rareté, taille, mutation) défilent, ralentissent et s'arrêtent un à un (secousse, étincelles), « SECRET ! » sur un tirage secret, phénix et cercle runique dès Légendaire ; un tap passe l'écran.

## 4. Événements déclencheurs (résumé)

| Événement serveur | Réaction du client |
|---|---|
| `Hatch` (éclosion) | révélation en interface, effets 3D par rareté, brillance, vignette, pulsation, cinématique si autorisée |
| `Notify` avec son `fanfare` | victoire du château : étincelles + cinématique de victoire |
| `Notify` avec son `event` et « Le Château » | cinématique d'entrée du château |
| `Notify` avec son `growl` ou `bark` | alerte « ❗ » |
| `Notify` avec son `hurt` ou `caught` | toute cinématique en cours est abandonnée immédiatement |

## 5. Réglages

`Config.Animations.vfx3d / uiFx / pulse`, `Config.VFX.quality` (« high », « medium », « low », nil), `Config.Cinematics.enabled / hub / eclosion / chateau`. Le plafond mobile (3 effets simultanés, 40 particules, pas de faisceau) s'applique automatiquement sur tactile.
