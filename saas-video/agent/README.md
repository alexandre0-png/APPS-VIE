# Prototype de l'agent de génération vidéo

Orchestrateur sans dépendance (Node 18+). Il ne génère pas de vidéo lui-même : il prépare des clips, vérifie les quotas, appelle un fournisseur vidéo et renvoie les URLs.

## Fichiers

- `config.mjs` : offres, quotas en secondes, tiers, styles.
- `planner.mjs` : demande → plan de clips de 5 s max.
- `quota.mjs` : quota mensuel en secondes et plafond quotidien (store en mémoire).
- `providers.mjs` : `MockProvider` (test, sans coût) et `HttpProvider` (à adapter au fournisseur choisi).
- `agent.mjs` : orchestration, contrôle global du quota avant toute génération, retry par clip.
- `cli.mjs` : ligne de commande.
- `agent.test.mjs` : tests.

## Lancer

```bash
node --test saas-video/agent/agent.test.mjs
node saas-video/agent/cli.mjs "un barista prépare un café en gros plan" --style realiste --duration 15 --plan pro --tier eco
```

Sans variables d'environnement, le fournisseur factice est utilisé.

## Brancher un vrai fournisseur

1. Choisir le fournisseur et lire sa documentation officielle (authentification, endpoint, format de réponse, statut asynchrone).
2. Adapter `HttpProvider.generate` : le code actuel suppose un endpoint synchrone `POST {baseUrl}/videos` qui renvoie `{ id, url }`. C'est un contrat d'exemple, pas celui d'un fournisseur réel. La plupart des API vidéo sont asynchrones : il faut interroger un statut jusqu'à obtention de l'URL.
3. Renseigner les variables :
   - `VIDEO_API_BASE_URL`
   - `VIDEO_API_KEY`
   - `VIDEO_MODEL_ECO`, `VIDEO_MODEL_STANDARD`, `VIDEO_MODEL_PREMIUM`
4. Vérifier avec un seul clip de 5 s avant tout test plus large.

## Limites connues du prototype

- Store de quotas en mémoire : perdu au redémarrage. À remplacer par une table Postgres.
- Pas de file de jobs : la génération est bloquante. À remplacer par une file asynchrone (ex. worker) pour les vraies vidéos.
- Pas de montage : pas de sous-titres, de musique ni de filigrane.
- Pas de contrôle de contenu : aucune détection de personnes réelles. Obligatoire avant production.
- Pas de LLM : le prompt est assemblé par règles, pas réécrit.
