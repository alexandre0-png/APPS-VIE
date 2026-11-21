# Déroulé de la partie, pièce par pièce

Fichier généré par `python3 tools/lua/gen_deroule.py` à partir de `src/shared/Chain.lua` et `src/shared/Deroule.lua` ;
ne pas l'éditer à la main (le test `test_deroule.py` vérifie qu'il est à jour).

Règle : une seule étape est active à la fois, dans l'ordre. Chaque passage reste fermé (trappe, porte, cave) avec le message
« Verrouillé : il te manque … » tant que la dernière étape de sa pièce n'est pas faite. Les objets des étapes futures sont inertes
(invites masquées). Sans progrès pendant 90 s, l'indice de l'étape s'affiche tout seul.

## Étapes

| # | Pièce | Objectif (barre du haut) | Objet clé | Passage ouvert | Indice (H) | Voix |
|---|---|---|---|---|---|---|
| 1 | Salle de la tombe et grenier ouest | Trouve le papier du code, dans le grenier | papier du code (surface plate) | — | Un papier froissé se cache sur une surface plate, dans le grenier. | — |
| 2 | Salle de la tombe | Lis les deux derniers chiffres dans un miroir (le texte est à l'envers) | miroir inquiétant (texte à l'envers) | — | Un miroir garde la fin du code. Le texte y est écrit à l'envers. | — |
| 3 | Salle de la tombe | Ouvre le coffret à bijoux avec le code complet | coffret à bijoux (code à 4 chiffres) | — | Le coffret à bijoux est posé sur la table de la salle de la tombe. | — |
| 4 | Salle de la tombe | Ouvre la malle du grenier avec la petite clé | malle (petite clé du coffret) | — | La petite clé du coffret ouvre la malle, dans la salle de la tombe. | — |
| 5 | Salle de la tombe | Prends la clé rouillée dans la malle | clé rouillée, au fond de la malle | trappe du grenier | La clé rouillée est au fond de la malle. | Le monstre s'éveille après le délai de calme (60 s en solo) : « Je te vois. » à la poursuite. |
| 6 | Premier étage (palier) | Rejoue la mélodie du gramophone sur la boîte à musique (premier étage) | gramophone puis boîte à musique | trappe du premier étage | Le gramophone joue trois notes. Rejoue-les sur la boîte à musique, dans le même ordre. | — |
| 7 | Hall | Règle l'horloge du hall sur la date gravée sur la plaque du cercueil | horloge du hall, date de la plaque du cercueil | — | Une date est gravée sur la plaque du cercueil. L'horloge du hall attend cette date, mois puis jour. | — |
| 8 | Salon, cuisine, bureau | Oriente les trois statues du rez-de-chaussée, toutes dans la même direction | trois statues à orienter | — | Les trois statues doivent regarder la même direction. La lampe UV montre la cible de deux d'entre elles. | — |
| 9 | Toute la maison ouverte | Rassemble les souvenirs | trois souvenirs (photos) | porte d'entrée | Les souvenirs traînent sur les meubles, dans les pièces ouvertes. Une lampe aide à les voir dans le noir. | — |
| 10 | Entrée | Sors par la porte d'entrée | porte d'entrée (trois souvenirs, clé, statues) | sortie vers le jardin | La porte d'entrée s'ouvre avec les trois photos, la clé rouillée et les statues résolues. | — |
| 11 | Jardin, escalier du sous-sol | Ouvre la porte métallique du sous-sol (au pied du mur sud, par le jardin) | porte du sous-sol puis porte métallique | cave | Les cris viennent d'en bas, au pied du mur sud : la porte du sous-sol, puis la porte métallique de la cave. | Une voix d'enfant appelle à l'aide, sous les pieds du joueur. |
| 12 | Cave centrale | Entre dans la cave | entrer dans la cave | — | La porte métallique est ouverte : avance dans la cave, quelqu'un y est enfermé. | — |
| 13 | Cave centrale | Dans la cave, lis les quatre documents et libère l'enfant dans la cage | cage de l'enfant, quatre documents, date de la plaque | cage | L'enfant est dans la cage, au fond de la cave. Lis les quatre documents de la maison, puis entre la date de la plaque devant la cage. | L'enfant remercie, puis suit le joueur ; le monstre le cherche. |
| 14 | Cave, escalier du sous-sol, jardin | Ressors de la maison par le sous-sol, avec l'enfant | porte du sous-sol, portail | — | Remonte par la porte du sous-sol, côté jardin. L'enfant te suit, et le monstre aussi. | — |

## Parties de la maison

| Partie | Pièces (MapData) | Étapes |
|---|---|---|
| Le grenier | tombe, gro | note, reflet, coffret, chest, key |
| Le premier étage | palier, chp, che, cha, sdb2, couloir, sdb, deb | melodie |
| Le rez-de-chaussée | hall, salon, cuis, sam, entree, bureau | horloge, statues, photos, sortie |
| La cave | cave, pn, ps, cel | cave, sous_sol, enfant, retour |

## Passages verrouillés

| Passage | S'ouvre à la fin de l'étape | Message |
|---|---|---|
| trappe du grenier | key | Verrouillé : il te manque la clé rouillée, au fond de la malle de la salle de la tombe. |
| trappe du premier étage | melodie | Verrouillé : il te manque la mélodie. Rejoue sur la boîte à musique les trois notes du gramophone. |
| porte d'entrée | photos | Verrouillé : il te manque les trois souvenirs, la clé rouillée et les statues bien orientées. |
| cave (par le jardin) | sortie | Verrouillé : sors d'abord de la maison par la porte d'entrée, la cave s'ouvre depuis le jardin. |
