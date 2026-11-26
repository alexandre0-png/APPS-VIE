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

## Lot 18 (petits objets de maison, agent Haiku) : scripts/blender_make_refonte_d.py
books_stack 75235784527086; branch_chandelier 81736669133938; clock_wall 95777609232622; coffee_maker 112911908053394; oven_stove 87903538253499; plant_pot_a 86148706778494; plant_pot_b 121510089986414; rug_round 90438557881098; stool_side 134719337565962; toaster 139790299453025; vase_big 123819297063677; coffee_table_round 112871489043894; speaker_pair 120384220519044; wall_lamp 73563604591192

## Lot 19 (gros meubles de maison, agent Sonnet) : scripts/blender_make_refonte_e.py
bed_double 73424212171108; dining_set 104316845432310; fridge_big 131419976234083; shelf_drawers 139964774272115; desk_study 102305030833988; kitchen_run 79053277599844; kitchen_upper 111169784434252; sofa_corner 107495439971094; tv_unit_stepped 108277232894442; wardrobe_tall 117500900219054

## Lot 17 (décor de carte : arbres, puits, îlot sakura, rochers, banc, parterre, agent Sonnet) : scripts/blender_make_refonte_c.py
bench_park 71149096082627; boulder_cluster 94606784141362; flowerbed 136250950680925; log_hollow 92331613804784; tree_dead 110319726621538; tree_pine_tier 89102403219316; tree_wide 86295807080862; island_sakura 77134124755209; stump_roots 77105687594948; tree_autumn 139640609512190; tree_fork 134023676934024; well_roofed 77148661041685

## Lot 20 (sons de l'énigme de la Mère Poule, synthétiques, en modération « Reviewing » au 25 nov, à vérifier)
berceuse_note1 85257974839127 (do) ; berceuse_note2 101445210941604 (mi) ; berceuse_note3 139374738574752 (sol) ; berceuse_note4 82316993375303 (do aigu) ; plume_ramassee 118620801437766 ; poule_glousse 125679862476345 ; secret_decouvert 119606421875553. Générés par une variante de scripts/audio_synth.py (boîte à musique).

## Lot 21 (10 œufs de rareté r1..r10, agent Sonnet) : scripts/blender_make_eggs_r.py
egg_r1 135765683612513; egg_r10 124299527536427; egg_r2 87965918516208; egg_r3 96993304097437; egg_r4 109265198341087; egg_r5 133048256610873; egg_r6 102115260137639; egg_r7 101573584229717; egg_r9 98454425446209; egg_r8 127835469690102
Échelle : se baser sur la hauteur de la pièce Coque (r5, r9, r10 dépassent 1 à cause de couronne/auréole ; r10 large 1,61 à cause des ailes). Coques r7/r10 non nommées Verre : le code force la transparence.

## Lot 22 (créatures P1 : numéros de la table C.2, agent Sonnet) : scripts/blender_make_pets_p1.py
#27 pet_cochon 120209362861524; #67 pet_demonenchaine 135810765401304; #70 pet_dragondecristal 83608898332171; #64 pet_dragondelave 104000037060333; #29 pet_herisson 97141542211988; #57 pet_loupdeglace 85636324524964; #28 pet_mouton 105709605466944; #68 pet_phenixsolaire 113957945777558; #26 pet_tortue 71698437334028; #76 pet_dragonceleste 106663728573110; #75 pet_seraphinlion 93690713012899; #62 pet_loupdecristaux 105118496375469
Dragon céleste : pas de Corps ni Queue (Seg1..Seg6) ; phénix : Jambe_G/D, pas de Patte_*. Ailes en L = disques fins.

## Lot 23 (créatures P2, table C.2, agent Sonnet) : scripts/blender_make_pets_p2.py
#30 pet_chauve_souris 122266421105736; #37 pet_cheval 86271823819731; #36 pet_crocodile 96697303823865; #50 pet_leopard_des_neiges 112945689300548; #43 pet_ours_brun 100651114276488; #31 pet_perroquet 115221106222960; #56 pet_phenix_de_feu 86984034098211; #63 pet_renard_a_neuf_queues 129679224173562; #44 pet_requin 74168168387947; #51 pet_requin_eclair 132943289797967; #32 pet_salamandre 132980424707847; #60 pet_tigre_aile_a_runes 74511340123175
Renard à neuf queues : Queue (animée) + QueueB..QueueI ; tigre 3947 faces (le plus lourd) ; crocodile couché ~0,95 de haut.

## Lot 24 (créatures P3, table C.2, agent Sonnet) : scripts/blender_make_pets_p3.py
#24 pet_abeille 102790865157502; #78 pet_baleine_des_etoiles 122467490138604; #23 pet_bebe_phoque 75024864159884; #22 pet_escargot 123238807000942; #21 pet_canard 138404880551003; #35 pet_castor 120115914325977; #25 pet_coccinelle 74508157385626; #34 pet_ecureuil_etincelle 96971397368899; #20 pet_grenouille 80608097786383; #33 pet_lievre_arctique 79906688348888; #77 pet_qilin_sacre 119496911538130; #19 pet_souris 121918353604833
Écarts : escargot Seg1..Seg6 + Tete ; baleine pas de Patte_* (nageoires = AileG/AileD) ; coccinelle sans AileG/AileD ; canard ailes = Bras_*.

## Lot 25 (créatures P5, table C.2, agent Sonnet) : scripts/blender_make_pets_p5.py
#66 pet_chimere_d_ombre 107851856102899; #74 pet_corbeau_couronne 128710572063568; #59 pet_golem_de_pierre 120688599001908; #52 pet_griffon 123941036439154; #58 pet_hydre_des_marais 98592552810541; #72 pet_loup_garou_citrouille 129301589385325; #53 pet_mammouth 96254656340357; #65 pet_oiseau_tonnerre 126200653094441; #55 pet_panthere_d_ombre 124133397709207; #54 pet_pegase 112611957470677; #73 pet_renne_etoile 91374905696445; #61 pet_serpent_foudre 81853803174670
Hydre : TeteG/TeteD ; chimère : TeteChevre + Queue_Tete ; serpent foudre Seg1..Seg5 ; corbeau sur Perchoir ; G = +x.

## Lot 26 (créatures P4, table C.2, agent Sonnet) : scripts/blender_make_pets_p4.py
#41 pet_aigle 117763124286242; #42 pet_anguille_electrique 105054666892128; #47 pet_belier_ardent 122718445916817; #45 pet_cameleon 120749563740834; #49 pet_flamant_rose 91307041810112; #39 pet_koala 120710439000059; #69 pet_leviathan 85629287384641; #38 pet_loup_gris 136090732261576; #48 pet_lynx_tonnerre 71472745327628; #40 pet_morse 82672464753777; #46 pet_renne 70993023882099; #71 pet_titan_de_l_orage 124318888739447
Anguille Seg1..Seg4 ; léviathan Seg1..Seg6 (+ Vague) ; titan Nuage socle ; flamant bec rose.

## Lot 27 (42 icônes d'interface en Decal : raretés, types, récompenses du calendrier ; agent Haiku) : scripts/gen_icones_ui.py
ATTENTION : ce sont des IDs de Decal ; pour afficher l'image, lire Decal.Texture après InsertService:LoadAsset (comme les textures), ou convertir en ID d'image.
egg_r1 127934484667125; egg_r10 106658286798870; egg_r2 90303465488088; egg_r3 133897962711845; egg_r4 107492649875193; egg_r5 81153824460002; egg_r6 131736092140777; egg_r7 105851181891208; egg_r8 79832611035411; egg_r9 94571875067666; r_boost_revenu 93587101573522; r_boost_vitesse 76153392233011; r_cadeau 133203541146640; r_calendrier 136982022925647; r_coffre 82453934753407; r_coins_l 89651368486077; r_coins_m 77804077779876; r_coins_s 100037045602015; r_cosmetique_traine 112422956807005; r_jeton_combat 78770783652851; r_mystere 96381471224410; r_parchemin_xp 72553197057463; r_plume 120153496188232; r_potion_chance 98934700828383; r_titre 123915288580926; type_ciel 130319463265184; type_eau 116853247438408; type_feu 84020103140683; type_foudre 125216098737198; type_glace 138517138957698; type_lumiere 136542493297233; type_ombre 97202454024141; type_plante 110639649572139; type_terre 112520404946573; ui_bouclier 136315741394095; ui_cadenas 71647030149825; ui_coeur 91429395170558; ui_epee 116607687889590; ui_etoile 99988006769146; ui_pastille_rouge 75154857237999; ui_trophee 117839068590655; ui_victoire_defaite 84125463363173

## Lot 28 (37 sons du lot 9-16 : éclosions r1..r10, types, combat, calendrier, tapis, kiosque ; tous APPROUVÉS ; agent Sonnet) : scripts/audio_synth_refonte.py
atk_ciel 111809409022959; atk_eau 126099928196969; atk_feu 81620112328213; atk_foudre 75059811348237; atk_glace 77653528704078; atk_lumiere 108376562226076; atk_ombre 135006463398132; atk_plante 111056707806818; atk_terre 77231920160184; battle_lose 75714072353851; battle_start 133857375212321; battle_win 74841129152048; belt_buy 73924816898255; belt_loop 127299224836728; calendar_claim 97907407134977; calendar_milestone 134993322632871; calendar_open 119109992802741; coin_pickup 95726825095665; egg_shake 101268169244225; hatch_r1 120743720926374; hatch_r10 70399111166131; hatch_r2 99352802477541; hatch_r3 130524252980200; hatch_r4 74396866627910; hatch_r5 71692383904268; hatch_r6 98693421307337; hatch_r7 130739946095614; hatch_r8 83413707310170; hatch_r9 127058227889279; house_levelup 110371127961423; jackpot_rare 90004480091860; kiosk_ambience 82723287691994; npc_ping 79333917653019; special_hit 86601967046565; special_ready 131456268494739; ui_click 127134008433069; ui_error 85896764648966

## Lot 29 (modèles du lot 15 : PNJ, calendrier, kiosque, événements ; 10 modèles, tous APPROUVÉS ; agent Sonnet) : scripts/blender_make_lot15.py
event_pumpkin 73142027959966; event_springarch 100036291919800; event_xmastree 139994644133468; hub_calendar 134196650002859; hub_kiosk 90238570290603; npc_bruno 132952760984236; npc_kai 132880746039280; npc_lina 102038009896523; npc_nora 81037598191401; npc_pip 123590742152774
Clés J.1 : npc.pip = npc_pip, npc.lina/bruno/kai/nora = npc_*, hub.calendar = hub_calendar, hub.kiosk = hub_kiosk, event.pumpkin/xmasTree/springArch = event_pumpkin/event_xmastree/event_springarch (minuscules).
Écarts : Pip 40 pièces, 9 de large (Pip x<0 + charrette x>0, origine au centre de l'ensemble) ; Kaï = 29 pièces dont le renard blanc (Renard_corps, Renard_tete, Museau, Renard_oreille×2, Queue×9) posé à x≈-3 ; Lina porte le koala (Accessoire = corps, Koala_*) ; Bruno marteau = Accessoire + Marteau_Fer ; Nora carnet = Accessoire. Calendrier 40 pièces (30 Cases__F5EBD7 : rangée du haut = jours 1-6, rangées de 6, case 30 en bas à droite ; coffre devant, bas centre). Kiosque : diamètre 15,4 (socle), hauteur 12,75, 4 panneaux PanneauBoutique(-Y)/PanneauCalendrier(+Y)/PanneauProba(+X)/PanneauClassement(-X), lanterne Lueur au centre. Citrouille : visage en Lueur_oeil×2, Lueur_nez, Lueur_bouche. Sapin 12,2 de haut : Guirlande_Lueur×3, Etoile_Lueur. Arche 9,65 de haut, 39 pièces. Orientation : devant = -Y, G = +x, pieds à z=0.


## Achats du lot 16 créés le 2026-11-26 (Chipe-Œufs, univers 10776613087 ; prix ≥ 799 confirmés par l'utilisateur)
| type | clé | id | prix |
|---|---|---|---|
| produit | CoinPackS | 3736703557 | 19 R$ |
| produit | EggR2 | 3736703563 | 15 R$ |
| produit | EggR3 | 3736703571 | 25 R$ |
| produit | LuckPotionMini | 3736703579 | 29 R$ |
| produit | EggR4 | 3736703588 | 49 R$ |
| produit | ArenaTickets | 3736703606 | 19 R$ |
| produit | StreakRestore | 3736703610 | 29 R$ |
| produit | EmoteVictory1 | 3736703619 | 39 R$ |
| produit | EmoteVictory2 | 3736703629 | 39 R$ |
| produit | EmoteVictory3 | 3736703634 | 39 R$ |
| produit | EmoteVictory4 | 3736703641 | 39 R$ |
| produit | EmoteVictory5 | 3736703649 | 39 R$ |
| produit | EmoteVictory6 | 3736703657 | 39 R$ |
| produit | EggR5 | 3736703667 | 99 R$ |
| produit | DoubleLuck | 3736703673 | 149 R$ |
| produit | SeasonPremium | 3736703683 | 399 R$ |
| produit | SeasonPremiumPlus | 3736703689 | 799 R$ |
| produit | EggR7 | 3736703695 | 799 R$ |
| produit | BundleLegend | 3736703706 | 999 R$ |
| produit | BundleRoyal | 3736703714 | 1499 R$ |
| passe | EggBagPlus | 2099454839 | 149 R$ |
| passe | Collector | 2099556764 | 249 R$ |
| passe | Lucky2 | 2102045961 | 349 R$ |
Déjà créés avant : CalendarCatchup produit 3736695392 (29 R$), EggSecret 3736452048, EggExclusive 3736452061, EggDivine 3736452072.
| produit | SeasonUpgradePlus (complément) | 3736704000 | 400 R$ |
| produit | BundleRoyalNoPass | 3736704205 | 1100 R$ (confirmé par l utilisateur) |
