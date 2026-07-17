# LANE 04 — Relais Garmin

Micro-service auto-hébergeable qui relie LANE 04 aux montres **Garmin**.
L'app iOS ne parle jamais directement à Garmin : ce relais garde le client
secret, orchestre **OAuth2 + PKCE**, puis pousse les protocoles validés vers la
**Garmin Training API** (création du workout + planification à la date choisie).

**Zéro dépendance** : Node.js ≥ 18.17, `npm start`, un fichier JSON comme
stockage. Pensé pour être hébergé par l'athlète lui-même (VPS, Raspberry Pi,
free tier) — LANE 04 reste gratuit, personne d'autre ne voit tes données.

## Prérequis Garmin

1. Compte au [Garmin Connect Developer Program](https://developer.garmin.com/gc-developer-program/)
   (gratuit, sur dossier) avec l'accès **Training API** approuvé.
2. Dans le portail, déclarer le redirect URI :
   `<PUBLIC_BASE_URL>/v1/garmin/oauth/callback`.
3. Récupérer `client_id` / `client_secret`.

⚠️ Les chemins Training API par défaut (`src/config.mjs`) suivent la doc
publique du programme — **à confronter à la spec du portail** une fois l'accès
accordé. Tout endpoint est surchargeable par variable d'environnement, sans
toucher au code.

## Lancer

```bash
cp .env.example .env         # renseigner GARMIN_CLIENT_ID / GARMIN_CLIENT_SECRET
set -a; source .env; set +a
npm start                    # → LANE 04 — relais Garmin sur le port 8080
npm test                     # tests du mapper (node --test)
```

En développement, l'app iOS (simulateur) accepte `http://127.0.0.1:8080` comme
relais (DEBUG uniquement) — réglage **CONSOLE › GARMIN RELAY**. En production :
**https obligatoire**, derrière un reverse proxy (Caddy, nginx) qui termine TLS.

## Contrat API (consommé par `Lane04/Data/GarminIntegration.swift`)

| Méthode | Chemin | Rôle |
|---|---|---|
| `GET` | `/healthz` | Sonde de vie. |
| `GET` | `/v1/garmin/oauth/start` | → `{ authorizationURL }` (state + PKCE générés, TTL 10 min). |
| `GET` | `/v1/garmin/oauth/callback` | Retour Garmin : échange le code, puis `302 lane04://garmin/oauth/callback?connection_token=…`. |
| `POST` | `/v1/garmin/workouts` | `Bearer <connection_token>` + payload LANE 04 → crée et planifie le workout. `201 { workoutId, scheduled }`. |
| `DELETE` | `/v1/garmin/connection` | Délie le compte (déréférencement Garmin best effort + oubli local). `204`. |

Erreurs : `401` lien absent/mort (se reconnecter), `422` payload invalide,
`502` faute côté Garmin. **Vérité de transmission** : si le workout est créé
mais que la planification échoue, la réponse reste `201` avec
`scheduled:false` — jamais une erreur qui pousserait l'app à réinjecter
(doublon garanti sur le compte Garmin).

## Sécurité

- Le `connection_token` remis à l'app est opaque (32 octets aléatoires) et
  stocké **hashé** (SHA-256) ; les jetons Garmin ne transitent jamais vers le
  téléphone.
- `state` OAuth à usage unique (TTL 10 min) lié à son `code_verifier` PKCE.
- Payload re-validé avec les bornes exactes de `ProtocolValidator` iOS
  (VMA 8…25, intensité 40…150 %, structure finie) avant tout appel Garmin.
- Aucune donnée d'entraînement conservée : le relais traduit et transmet.
- Stockage fichier (`data/store.json`, mode 600) : suffisant pour un relais
  personnel. Multi-athlètes → migrer `src/store.mjs` vers SQLite/Postgres.
