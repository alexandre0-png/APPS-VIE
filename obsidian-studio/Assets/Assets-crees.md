---
type: assets
---
# Assets créés par Claude (compte ahmzk0)
## Modèles Blender lot 1 (obsolètes : un seul bloc sans couleurs séparées)
- CleOr **128263149076283** (clé dorée)
- CoffretAncien **80816541343966**
- HorlogeComtoise **121788657121996**
- PoupeeAncienne **114751010380157**
- BougieChandelier **118027923730609**
Source : `scripts/blender_make_models.py`. Échelle et orientation dans Roblox non vérifiées : redimensionner par `GetExtentsSize`.

## Sons synthétiques FFmpeg (OGG)
- AmbianceGrenier **70845517493066** (drone grave 24 s) : modération en cours de revue au 2026-11-20.
- battement_coeur (12 s) et grincement_porte (2 s) : générés, pas encore téléversés.

## Modèles Blender lot 2 (2026-11-20, 35 modèles approuvés, pièces séparées par matériau)
Convention : chaque pièce s'appelle `Nom__RRGGBB`. Le chargeur lit le suffixe, applique `Color3.fromHex`, car Roblox ignore les couleurs du FBX sans texture. Source : `scripts/blender_make_all.py` (bibliothèque `scripts/blender_lib.py`). Téléversement : `scripts/blender_upload_all.py`.
- **Grenier** : CleOr 71927105620016 ; CoffretAncien 135334916682974 ; HorlogeComtoise 127086141131615 ; PoupeeAncienne 137798724739586 ; BougieChandelier 91265848520746 ; Armoire 88627357314275 ; Commode 116600254156058 ; Berceau 73900289399193 ; ChevalBascule 74320735179635 ; MiroirAncien 134489196998276 ; Malle 94690600145377 ; Statuette 107399380407320 ; CadrePhoto 86021806351640 ; OmbreRampante 101328489566505
- **Chipe-Œufs** : OeufCommun 100023720665590 ; OeufRare 74975545149168 ; OeufEpique 86639017295697 ; OeufLegendaire 137014263068694 ; OeufMythique 110535599163330 ; OeufSecret 95190117262171 ; PetPoussin 122665615732907 ; PetRenard 125436205733282 ; PetPanda 113006978203286 ; PetDragonnet 134284711848469 ; PetLapin 88649442626593 ; PetFantome 129116477413499 ; Arbre 88144895198576 ; Sapin 79188790509321 ; Rocher 132852439679625 ; Buisson 81559211389899 ; PontBois 72821096584538 ; Cabane 121389844339916 ; Barriere 98207856976488 ; Fontaine 87696152276058 ; NidOeufs 85337440768183
- Total : environ 10 000 faces pour 35 modèles ; le plus lourd (PetPanda) 1 056 faces.
- Vignettes : brouillons Blender (Grenier et Chipe-Œufs), qualité insuffisante pour publier, à refaire.

## Modèles Blender lot 3 (Chipe-Œufs, 31 modèles approuvés, script `scripts/blender_make_oeufs2.py`)
- Décor, gardiens, château, pièges, sol : props.mill 108678125939354 ; guards.dog 103939852527807 ; guards.wolf 97774277975586 ; guards.bear 70929301247964 ; guards.knight 79935066561502 ; props.castle 85826335560323 ; castle.wall 136500159645250 ; castle.tower 120194370584366 ; castle.door 81799010490650 ; castle.floor 87526275066787 ; trap.spikes 109204482572726 ; trap.blade 83758069602274 ; trap.ball 97316525004480 ; props.chest 81643274706684 ; props.torch 89605986322384 ; props.flag 110279682395149 ; props.sign 74276869239897 ; props.pen 117636221218047 ; ground.grass 108336655087221 ; ground.path 129255762203803 ; ground.plaza 129476241883133 ; props.lamp 137473402121117 ; props.bench 123958905099505
- Pets supplémentaires : Chat 81991111371408 ; Chien 90815266946917 ; Hamster 130387777043821 ; Hibou 95489512823854 ; Licorne 119358850090330 ; Lion 73493068085290 ; Manchot 73235151647339 ; TRex 113312935651236

