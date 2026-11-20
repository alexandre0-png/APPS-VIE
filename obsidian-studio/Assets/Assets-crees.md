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

## Modèles Blender lot 4 (Hôpital et Grenier, 29 approuvés, `scripts/blender_make_hg.py`)
- **Hôpital** : ArmoireMedicale 86941482778850 ; CarteDepart 83163963771412 ; Casier 96593981421695 ; ChariotMedical 78435000269542 ; Civiere 113009736415170 ; ClePorte 129267549369519 ; Extincteur 130557285293106 ; FauteuilRoulant 113902369020348 ; GuidePetit 125524818375330 ; LampeOperation 99186888120628 ; Lavabo 89006628594014 ; LitHopital 101882675284453 ; MurLabyrinthe 94088410522423 ; PanneauSortie 110260059378186 ; Perfusion 99245134234700 ; Rideau 93550029012886 ; TableOperation 114609718825701 ; Voiture 102838872864731
- **Grenier (suppléments)** : Cheminee 127626819974178 ; Escalier 134240189869154 ; Etagere 76212522336973 ; Gramophone 99475660293991 ; Lustre 135294864655941 ; MachineCoudre 124715650479605 ; PorteAncienne 129943433961170 ; TapisRond 99100525426156 ; Telephone 139304662558987 ; ToileAraignee 71110850265760 ; Valise 136114731977294

## Modèles Blender lot 5 (Grenier, mobilier de BLENDER_REQUESTS.md, 25 approuvés, `scripts/blender_make_g2.py`)
armoire_toilette 128128467516107 ; baignoire 81854062482660 ; barrique 108166293605074 ; caisses 89142087734544 ; canape 85086079052709 ; cercueil 97146110981447 ; chaise 97926582469965 ; coffre_jouets 118394284398196 ; coffre_verrouille 90844346755064 ; console 127180262193443 ; cuisiniere 76790495265936 ; cuve 85621038139046 ; etabli 124510607976600 ; etagere 96130815912348 ; fauteuil 84731331370269 ; frigo 77833906083470 ; lampadaire 92735211656049 ; lavabo 109380958615258 ; lit_double 135445479170017 ; pied_lit 129217921305648 ; plante 115245941716953 ; portemanteau 129593495246898 ; table_salle 92569428619047 ; vitrine 82264063741947 ; wc 135608112766747

## Lot 6 (Grenier : moulures, fenêtres, escalier ; 10 modèles + 8 textures tuilables, `scripts/blender_make_g3.py`, `scripts/blender_textures.py`)
Les textures sont des décals : lire `Decal.Texture` après `InsertService:LoadAsset` pour obtenir l'image.
g_applique 114023857878257 ; g_balustrade 75136739107081 ; g_encadrement 125000444415052 ; g_fenetre_rideaux 126909624367682 ; g_fenetre_ronde 71510822261833 ; g_marche 101885017410350 ; g_moulure 75784159506222 ; g_plinthe 92565174748095 ; g_radiateur 113203803952444 ; g_soupirail 103729918302456 ; tex_dalles_cave 107078290448335 ; tex_damier_cuisine 74886659758502 ; tex_faience_murale 80018384734004 ; tex_lames_plancher 137828535744065 ; tex_marbre_veine 82505741913633 ; tex_papier_enfant 134002350904585 ; tex_papier_fleuri 133522614389829 ; tex_parquet_chevrons 103808199880931

## Mise à jour en place (2026-11-21)
Les 130 modèles des lots 2 à 6 ont été régénérés avec biseaux (segments 2, angle 35°) et lissage automatique, puis mis à jour SANS changer leurs IDs (`PATCH /assets/v1/assets/{id}`, nouvelle révision, tous approuvés). Script : `scripts/blender_update_all.py` ; la bibliothèque `scripts/blender_lib.py` applique le biseau (variable d'environnement `BEVEL=1`). Aucun changement de code nécessaire dans les jeux : le chargement lit la dernière révision.

