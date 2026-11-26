---
type: journal
---
# Journal des décisions
- 2026-11-12 : création de l'agent de gestion et de ses sous-agents (dev, QA, sécurité, audit).
- 2026-11-14 : hub et partie dans la MÊME expérience (ReserveServer, MemoryStore et DataStore sont limités à une expérience). Rôle par PlaceId.
- 2026-11-14 : lieu de départ impossible à changer dans le tableau de bord : inversion des rôles. Grenier : hub 77452764500707, partie 88091909899710. Chipe-Œufs : hub 115261336085924, partie 87012762353093.
- 2026-11-14 : cause racine du joueur dans le ciel : `require` fautif dans Shop.lua. StreamingEnabled désactivé en plus.
- 2026-11-19 : IDs catalogue intégrés dans les jeux 1, 2, 3.
- 2026-11-20 : Max Players réglé par l'API (Grenier 2, Chipe-Œufs 5) ; lieux de partie renommés.
- 2026-11-20 : clé API avec permissions minimales (universe-places, universe, universe.place, Assets). Décision : la mémoire du studio vit dans le dépôt (`obsidian-studio/`), copiable dans Obsidian ; ni Honcho ni lecture directe d'Obsidian.
- 2026-11-20 : Blender (bpy) opérationnel, 5 modèles approuvés. FFmpeg opérationnel, 1 son téléversé.
- 2026-11-20 (soir) : le Grenier ne se lançait plus chez l'utilisateur après les publications v22/v15 (modèles Blender, 095bf86) et v23/v16 (style et bannières, de5b47a). Retour arrière : republié f98bdc7 (hub v25, partie v17). Cause probable à confirmer : chargement des modèles avant la carte, ou erreur du script client (jamais exécuté dans le faux Roblox). La session Jeu 2 doit livrer un commit « stable » puis les modèles par commits séparés.
- 2026-11-20 (soir) : Chipe-Œufs, e456d4c non publié (6 échecs sous Lune : probabilités et erreur client ligne 1174). Retours de l'utilisateur : amis qui rejoignent même une partie solo, œufs énormes à l'éclosion, graphismes à refaire avec Blender, loups à refaire (dégâts, perception, passer derrière), missions et mode Château, boutique d'économie et boutique payante.
- 2026-11-20 (soir) : Jeu 1 débloqué : réponses OUI aux trois questions (meubles, indice de la clé, personnage guide), plus animation finale et carte de départ.
- Convention : chaque session de jeu liste ses besoins de modèles dans `BLENDER_REQUESTS.md` de son dossier ; la gestion les crée avec `scripts/blender_make_all.py` et les téléverse.
- Rappel : publier une version testée seulement ; en cas de doute, retour arrière sur la dernière version sûre.

- 21 nov : l'utilisateur supprime le Jeu 2 (Sortir Du Grenier) et décale la numérotation : Hôpital 1, Chipe-Œufs 2, zoo 3, PvP 4. Session Grenier archivée, notes déplacées dans Archive/, expérience Roblox à supprimer par l'utilisateur (non faisable par API), branche de code conservée. Cinématiques déjà coupées (partie v34).
- 26 nov : règles de design de l'utilisateur pour Chipe-Œufs (lots 9+) : revenu et force au combat strictement croissants avec la rareté (≥ x1,8 et ≥ x1,25 entre paliers), profils différents au sein d'une rareté (Tank/Attaque/Vitesse/Équilibré, ±8-15 %), économie pièces plus chère et 4 à 12 fois plus longue que le chemin Robux, joueur gratuit toujours en progression, œufs Secret/Exclusif/Divin jamais vendus en Robux. Envoyé à la session Jeu 2 avec tests obligatoires.
