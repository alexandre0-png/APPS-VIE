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

## Sons synthétiques (2026-11-21, 31 téléversés, modération en cours au moment de l'écriture ; `scripts/audio_synth.py`, `scripts/audio_upload.py`)
aboiement 114298173898782 ; achat 113679524214656 ; ambiance_chateau 123273835786709 ; ambiance_prairie 89353143614427 ; battement_coeur 134398301938123 ; boulet_roule 93517357278251 ; chuchotement 97685445181857 ; cle_ramassee 94023442831959 ; clic_achat_refuse 75136819922416 ; clic_menu 123764673506668 ; coffre_ouvre 120351652437677 ; coup_degat 97370499111519 ; eclosion_epique 111875674907537 ; eclosion_legendaire 90908436660215 ; eclosion_pop 84390525214058 ; eclosion_rare 111600385012831 ; eclosion_secret 124766540033525 ; fanfare_victoire 126605194205875 ; grincement_porte 72276002070833 ; grognement_loup 72413498813091 ; horloge_tic 72367631338816 ; lame_tourne 84863036780507 ; marche_escalier 80053909075631 ; murmure 119844783294265 ; pas_bois 71222524066643 ; pas_courses 130512281096828 ; pics_sortent 115413112102226 ; piece 110088134711268 ; porte_verrouillee 95280236603158 ; sting_monstre 123098158629366 ; vent_grenier 119514716471672

## Textures lot 2 (14 décals tuilables 1024, approuvés, `scripts/blender_textures2.py`)
bois_planches 136082705365776 ; briques_cave 110243665972154 ; carreaux_bleutes 128807555994876 ; dalles_chateau 90865253086689 ; eau 72897294450066 ; herbe 122917279401510 ; moquette_bleue 112143370146391 ; moquette_bordeaux 76003718416351 ; moquette_verte 71770506233998 ; pierre_chateau 87480813124386 ; platre_fissure 89934903274963 ; rideau_tissu 134198227829676 ; sable 83914325296472 ; terre_chemin 84243738566468

## Modèles VFX (13 approuvés, pièces blanches à recolorer, `scripts/blender_make_vfx.py`)
vfx_ailes 139237669898830 ; vfx_bouclier 135593787305812 ; vfx_cercle_runique 78887954880607 ; vfx_cone_lumiere 98452721754905 ; vfx_cristaux 84932789634035 ; vfx_etincelles 116678428336273 ; vfx_etoile 73454147532566 ; vfx_halo 123922819073158 ; vfx_pilier_lumiere 136359342334671 ; vfx_rayons 88635068911286 ; vfx_spirale 130478050046509 ; vfx_torii 105301464189354 ; vfx_onde 125557026046168


## Lot 8 (pets restants, Chipe-Œufs) : script scripts/blender_make_pets4.py
PetTigre 72370255271127 (index 11) ; PetKraken 123754319737365 (15) ; PetCalmar 85626350359383 (17) ; PetWyrm 127368682215579 (18). Tous approuvés. Les 18 espèces ont un modèle.

## Lot 9 (Grenier lot 4 : cave et meubles) : scripts/blender_make_g2b.py
g_cage_enfant 102154280370105 ; g_matelas_enfant 91319011192266 ; g_chaine_cave 132630002585073 ; g_chevet 106047201970729 ; g_table_basse 129483387884426 ; g_meuble_tv 73089944142322 ; g_plan_travail 79340837686582 ; g_penderie 78040764946413 ; g_gueridon 95132769826424 ; g_banc 87911810523146 ; g_bidon 135009865593146 ; g_coffre_cave 97448512398637 ; g_buffet 124370863796629. Envoyés à la session Jeu 2 pour branchement.

## Lot 10 (Chipe-Œufs : déco, terrain, cabanes, niveaux de base) : scripts/blender_make_g3b.py
deco_flower_a 77356084419297 ; deco_flower_b 75380956155225 ; deco_flower_c 111315415429762 ; deco_tuft 87978041093798 ; deco_stone_flat 136754104457535 ; deco_stone_round 87559674928022 ; deco_lantern 104138982529608 ; deco_sign_stars 123744671851193 ; terrain_cliff_a 77185775444063 ; terrain_cliff_b 121767734121074 ; terrain_cliff_corner 110100977206117 ; terrain_stairs 105161635046156 ; terrain_waterfall 129292144451409 ; terrain_islet 128405076287969 ; props_bridge_rail 112917439859012 ; props_fence_corner 120728100461105 ; props_fence_gate 95541995292351 ; props_hut_small 93190979240574 ; props_hut_big 128414703286969 ; base_level1..8 : 97252816676038, 81995835244074, 77426422736227, 95370892804658, 75516398880390, 108065975809605, 83929759854266, 100223033827392. Envoyés à la session Jeu 3.

## Lot 11 (Chipe-Œufs : arbres, chemins, protections d'œufs) : scripts/blender_make_g3c.py
tree_oak_a 115675817596242 ; tree_oak_b 139178488755477 ; tree_birch 86165293471213 ; tree_pine 134548154871906 ; tree_sakura 136998832791777 ; tree_round 128198214830836 ; path_straight 85121318662290 ; path_curve 101412637646543 ; path_stones 119316046353622 ; egg_dome 114304098897950 ; egg_nest_fence 101252453233834 ; egg_cage 98653120562597 ; egg_shield 73837494094507. Envoyés à la session Jeu 3.

## Lot 12 (Chipe-Œufs : décor village/île, inspiré des images de l'utilisateur) : scripts/blender_make_g3d.py
scn_puits 93457733638103 ; scn_pin_haut 103664392312435 ; scn_pont_pierre 71167399273394 ; scn_maison_colombages 108434085196211 ; scn_tour_cloche 117760736577913 ; scn_rocher_a 109597978140541 ; scn_rocher_b 91218401630144 ; scn_rocher_c 126837715911422 ; scn_ile_sakura 103275800553270.
## Lot 13 (Grenier : mobilier supplémentaire) : scripts/blender_make_g2c.py
m_buffet_bas 104815439105065 ; m_placard_haut 136718584759461 ; m_fauteuil_osier 73883595440989 ; m_table_ronde_pied 134181576477835 ; m_chaise_accoudoirs 84730866248614 ; m_suspension 140374171340658 ; m_chandeliers 100599765357745 ; m_renard_statuette 127546013937541 ; m_livres 99596807748651 ; m_tabouret_bar 93270940759227 ; m_gueridon_lampe 93677754196340.

## Lot 14 (21 nov) : pets v2 style chibi, mis à jour EN PLACE (mêmes IDs) : scripts/blender_make_pets_v2.py
Les 18 pets (Poussin à Wyrm) sont remplacés par une version chibi (grosse tête, grands yeux à reflet, joues roses, pieds). IDs inchangés (table Config.Assets.pets de Chipe-Œufs). Le jeu charge la dernière version : aucune republication nécessaire.

## Lot 16 (accessoires de marché et décor, refonte Chipe-Œufs) : scripts/blender_make_refonte_b.py (agent Haiku)
stall_a 121243958605530 ; stall_b 94658977878853 ; crate_stack 72797022625881 ; barrel_pair 102360413338352 ; hay_bale 99760241706274 ; reeds 83409451845816 ; lily_pad 108143670859973 ; bush_round 72736930746142 ; sign_base 121260374584222 (sans lettrage) ; flag_banner 72351168707999 ; lantern_post 116378599429951 ; well_small 140033477297106.

## Lot 15 (refonte Chipe-Œufs : maisons de base, dôme, tapis roulant, Grand Œuf, arène) : scripts/blender_make_refonte_a.py (agent Sonnet)
house_lvl2 83993710226197 (26,6×28,6×21,3) ; house_lvl3 137211706941591 ; house_lvl4 131395542579523 ; house_lvl5 86282878742281 ; house_lvl6 92231252125110 ; house_lvl7 79107809937066 ; hub_dome 106786001814640 (60×60×24,4) ; conveyor_belt 110718997928428 (12×4,1×1,5) ; conveyor_end 107430030694559 ; grand_oeuf 140225439366673 (13,6×13,6×15,7 ; runes Flamme_Rune*) ; arena_colosseum 105443469311651 (70,8×70,8×21). Maisons : bâtiment à l'arrière (+y), escalier vers l'avant (-y). Limites : lvl4 sans portail de garage, lvl5 sans la terrasse de référence, petit défaut d'ombrage sur conveyor_end.
