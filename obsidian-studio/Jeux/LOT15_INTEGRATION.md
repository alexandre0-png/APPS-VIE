# Lot 15 : brief d'intégration (préparé par la gestion, 2026-11-26)

Spec de référence : `LOTS_9_PLUS.md` sections F (PNJ), G (récompenses, quêtes, rotation, événements) et « Lot 15 » de K. L'utilisateur a fixé l'ordre : 9b, intégration lot 10, 8B, **15, 16**, puis 11–14.

## Écarts et décisions qui PRIMENT sur la spec
1. **Calendrier de 30 jours** : la table finale du lot 9b remplace G.3 (J3 Légendaire, J7 Épique, J10 Légendaire, J20 Mythique, J30 tirage 40 % Ultra Rare / 45 % Mythique / 15 % Secret, une récompense chaque jour). Ne pas réécrire G.3 : réutiliser le module du 9b.
2. **Raretés à 10 niveaux** (lot 9) : toutes les récompenses « Œuf {rareté} » passent par `Config.TIERS` et les TIER_GATE, jamais de rang codé en dur. Les noms : Secret/Exclusif/Divin ne sont jamais donnés par les PNJ, la série ou les quêtes (achat ou événement uniquement ; l'Exclusif s'obtient aussi avec 150 plumes d'événement).
3. **Espèces des PNJ** : Koala (Lina), Ours brun (Bruno), Renard à neuf queues (Kaï) ; si elles n'existent qu'au lot 11, utiliser un repli procédural (comme les lots précédents) et brancher les vrais modèles ensuite. Les équipes PNJ n'utilisent que des espèces existantes.
4. **Aucun PNJ ne vend ni n'accepte de Robux**, aucun échange entre joueurs, règles anti-abus F.4 en tests (10 000 offres générées).
5. **Anti-harcèlement** : réglage « Ne plus être interpellé » (`npc.off`) visible dans le menu, sons `npc_ping` seulement.

## Modèles et assets déjà prêts
- Sons : npc_ping, calendar_open/claim/milestone, jackpot_rare, ui_click/error (ids dans `Assets/Assets-crees.md`, lot 28).
- Icônes : r_calendrier, r_cadeau, r_coffre, r_plume, r_potion_chance, r_parchemin_xp, r_jeton_combat, r_titre, r_boost_*, ui_pastille_rouge (lot 27).
- Modèles en cours de création (lot 29, agent Sonnet) : `npc.pip`, `npc.lina`, `npc.bruno`, `npc.kai`, `npc.nora`, `hub.calendar`, `hub.kiosk`, `event.pumpkin`, `event.xmasTree`, `event.springArch`. IDs attendus dans `Assets/Assets-crees.md` section « Lot 29 ». Repli procédural obligatoire si un ID est vide.

## Étapes
1. `Npc.lua` pur + `Config.NPCS`, `Config.NPC_ENCOUNTER`, dialogues F.3, serveur : offres à identifiant unique, 60 s, liées au userId.
2. `Rewards.lua` : série 7 jours (G.1), grâce (G.2), calendrier du 9b, quêtes bonus et hebdomadaires (G.4), `eggBag` (10 places, jamais de perte).
3. `Config.WEEKLY_ROTATION` (9 semaines déterministes), `Config.EVENTS_CAL` (données), plumes d'événement (plafonds/jour), week-end chanceux, heure dorée 18-19 h UTC.
4. `Data.lua` : champs `npc`, `cal`, `grace`, `weekly`, `event`, `eggBag` avec migration idempotente depuis v11 (nouvelle version de profil, test de relecture).
5. Client : bulle « ❗ » et dialogues PNJ (jamais pendant vol/cinématique/œuf porté/poursuite), panneau série + calendrier (kiosque), notification rouge.
6. Tests : ceux de la section « Lot 15 » de K + 35 jours simulés (dont 4 manqués), reconnexion ou changement de serveur sans relancer une rencontre.
7. Revue sécurité (économie : aucune duplication d'œufs, reçus, quotas serveur).

## Livrable
Commit non-WIP « Lot 15 », tests verts, rapport : écarts, À tester dans Studio.
