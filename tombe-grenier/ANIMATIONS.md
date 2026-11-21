# Catalogue des animations

Tout est désactivable : `Config.Animations.Enabled` (tout), `Config.Vfx.Enabled`, `Config.Cinematics.Kit`, et un drapeau par geste d'interface (`UiBounce`, `UiPress`, `UiShine`, `UiFloat`, `UiPulse`). Ambiance horreur : teintes froides, peu de particules, rien de long.

## Effets visuels (`src/shared/VfxKit.lua`)
Les 13 modèles Blender (pièces blanches `Nom__FFFFFF`, Material Neon) sont chargés par le serveur après la carte, copiés dans `ReplicatedStorage.Vfx` et recolorés par thème. Sans modèle, une forme néon de secours joue le même effet.

| Préréglage | Pièces (modèle) | Durée | Courbe | Thème | Déclencheur |
|---|---|---|---|---|---|
| `aura_runique` | cercle runique, halo | 2,6 s | Quint, Sine | froid | étape de la chaîne accomplie (cercle discret au sol) |
| `aura_ailes` | ailes, halo | 2,2 s | Back, Sine | pâle | enfant retrouvé (plan `enfant_retrouve`) |
| `onde_de_choc` | onde | 0,9 s | Quint | rouge | sursaut (Effect Scare) |
| `pilier_revelation` | pilier de lumière, étincelles | 3 s | Elastic, Sine | or | objet précieux (plan `objet_precieux`), avec Beam hors téléphone |
| `bouclier` | dôme | 2,4 s | Back | froid | disponible (Highlight sur l'objet visé hors téléphone) |
| `etincelles` | nuage d'étincelles | 1,8 s | Sine | pâle | disponible |
| `spirale_montee` | spirale | 2 s | Quint | pâle | passage du monstre à moins de 30 studs (toutes les 4 s) |
| `portail_torii` | torii, halo, rayons | 3 s | Back, Sine | or | disponible (Beam hors téléphone) |
| `lueur_enigme` | cristaux, étoile | 2,4 s | Back, Sine | or | objet de l'étape active à moins de 45 studs (toutes les 6 s) |

Qualité (`VfxKit.quality`, `Config.Vfx.Quality`) : **haut** (ordinateur : 8 effets, 120 particules par émetteur, Beam et Highlight), **moyen** (tablette : 5, 80, Highlight), **bas** (téléphone : 3 effets simultanés, 40 particules par émetteur, ni Beam ni Highlight, 2 pièces au plus). Tout est sous `pcall`, nettoyé par `Debris`.

## Plans de caméra (`src/shared/CinematicKit.lua`)
Au plus 8 s, passables (Espace, Échap, Entrée ou bouton « Passer »), refusés en danger (poursuite, monstre à moins de 25 studs, caché, mort, autre cinématique). Caméra, champ de vision, flou, teinte et personnage sont restaurés dans tous les cas (fin, passage, erreur, mort, personnage retiré). Une seule cinématique à la fois : la seconde demande est refusée.

| Plan | Durée | Prises | Événement déclencheur |
|---|---|---|---|
| `reveil_cercueil` | 5 s | travelling lent avec flou qui se dissipe ; orbite courte du regard | fin de l'arrivée (Effect Cine `arrival`) |
| `apparition_monstre` | 5 s | travelling arrière avec tremblement ; dolly zoom (champ 85 à 45, Back) | première apparition (Effect Cine `apparition`), même monstre proche |
| `objet_precieux` | 4 s | orbite en gros plan teintée or ; dolly lent ; pilier de lumière | étapes `coffret` et `key` accomplies |
| `porte_ouvre` | 4 s | plan large qui avance ; dolly vers la porte, grincement | étape `cave` accomplie |
| `sortie_soussol` | 7 s | plongée montante, puis plan aérien teinté de jour | étape `retour` accomplie |
| `enfant_retrouve` | 5 s | orbite lente autour de la cage de la cave ; dolly, aura d'ailes | étape `enfant` accomplie (l'enfant est libéré dans la cave) |
| `fuite_finale` | 8 s | poursuite par l'arrière ; plongée avec carton « Tu es sorti. » ; carton « Sortir Du Grenier » (générique) | fin victorieuse (Effect Cine `win`) |

Trajectoires : `travelling`, `orbite` (rayon constant), `plongee`, `dolly` (avec variation du champ de vision) ; easings `linear`, `Sine`, `Quad`, `Quint`, `Back`, `Elastic` ; options de prise : `shake`, `slow`, `title`, `blur`, `tint`, `focus`.
Les cinématiques longues d'origine (`Cinematic.lua` : arrivée, descente, fins 3 et 4) restent disponibles ; le kit les interrompt proprement quand l'une des deux démarre.

## Interface (`src/client/UiFx.lua`)
Apparition avec rebond (bannières de zone et d'étape, bouton Rejouer), compteur qui défile (souvenirs), bouton écrasé puis élastique (boutons tactiles), balayage de brillance (Rejouer), texte flottant (« Trouvé »), flash de vignette (sursaut), pulsation légère ColorCorrection et Bloom à chaque étape (jamais sur téléphone).
