# Encadrement des loyers à Paris

[![CI](https://github.com/Chahine-tech/encadrement-loyers-paris/actions/workflows/ci.yml/badge.svg)](https://github.com/Chahine-tech/encadrement-loyers-paris/actions/workflows/ci.yml)

API Rails qui importe les loyers de référence de l'encadrement des loyers parisien (open data de la Ville de Paris) et permet à un locataire de vérifier si son loyer respecte le plafond légal.

Projet personnel construit pour monter en compétence sur Ruby on Rails.

**Stack** : Ruby 3.4, Rails 8.1 (mode API), PostgreSQL 18, Redis + Sidekiq, Faraday, RSpec, RuboCop, Docker Compose.

## Lancer le projet

Prérequis : Docker.

```bash
docker compose up -d --wait                                # API, Sidekiq, PostgreSQL, Redis (crée la base)
docker compose exec web bin/rails import:reference_rents   # importe les 17 920 loyers de référence (~40 s)
curl -s "localhost:3001/api/v1/comparisons?district_id=67&rooms=2&construction_period=before_1946&furnished=false&surface=30&rent=1100"
```

Tests et lint :

```bash
docker compose exec web bundle exec rspec
docker compose exec web bin/rubocop
```

Ports exposés sur la machine : API sur `3001`, PostgreSQL sur `5433` (pour ne pas entrer en conflit avec une installation locale).

## Endpoints

| Méthode | Route | Rôle |
|---|---|---|
| GET | `/api/v1/districts` | Les 80 quartiers, plus les années et époques disponibles (pour construire un formulaire) |
| GET | `/api/v1/comparisons` | Compare un loyer au loyer de référence : `below_min`, `within_range` ou `above_max`, et le dépassement en € |
| GET | `/api/v1/reports/zones` | Loyer de référence moyen par zone (agrégation SQL) |
| GET | `/api/v1/reports/districts` | Même chose par quartier |

Paramètres de `/comparisons` : `district_id`, `rooms`, `construction_period` (`before_1946`, `from_1946_to_1970`, `from_1971_to_1990`, `after_1990`), `furnished`, `surface` (m²), `rent` (€ hors charges) et `year` (facultatif, l'année la plus récente par défaut). Les rapports acceptent `year`, `rooms`, `furnished` et `construction_period`.

Erreurs, toujours au même format `{ error, message, details }` : 422 si les paramètres sont invalides (avec tous les champs en erreur), 404 si aucune référence ne correspond, 400 si la requête est mal formée.

## Architecture

```
app/
  connectors/paris_open_data/
    client.rb        # HTTP uniquement : pagination, timeouts, retries, erreurs typées
    importer.rb      # transforme les données de l'API et les upsert en base
  jobs/import_reference_rents_job.rb   # job Sidekiq : retry_on / discard_on
  models/            # ReferenceRent, ImportRun (historique des imports)
  services/rent_comparison.rb          # logique métier, objet Ruby + ActiveModel
  queries/rent_report.rb               # agrégations SQL pour les rapports
  serializers/                         # forme du JSON public
  controllers/api/v1/                  # gestion d'erreurs centralisée (rescue_from)
```

## Ce que j'ai fait / pas fait

**Fait**

- Un connecteur vers l'API Opendatasoft de la Ville de Paris, isolé du reste de l'application et testé sans réseau (WebMock).
- Un import idempotent dans un job Sidekiq, avec un historique de chaque exécution (`import_runs`).
- La comparaison d'un loyer, deux rapports agrégés en SQL et une API versionnée.
- 62 tests RSpec (modèles, connecteur, import, job, service, endpoints) et un CI GitHub Actions (tests sur PostgreSQL 18, RuboCop, Brakeman, bundler-audit).

**Pas fait**

- **Le front** React + Tailwind.
- **Une planification de l'import** : les données changent une fois par an, l'import se lance à la main. La suite serait un cron avec `sidekiq-cron`.
- **Du cache** : les endpoints de référence s'y prêtent bien (cache Redis, vidé à la fin de l'import).
- **La recherche par adresse** : il faut connaître son quartier, il n'y a pas de géocodage.
- **De l'authentification** : il n'y a aucun endpoint d'écriture. Un déclenchement de l'import par l'API devrait être protégé.
- **Le complément de loyer** : un loyer au-dessus du plafond peut être légal si le bailleur justifie un complément. L'API le signale comme `above_max` sans pouvoir le savoir.
- **Le déploiement** : le `Dockerfile` de production généré par Rails n'a pas été testé.

## Décisions

**Un index unique comme clé de l'import.** Une ligne est identifiée par `(year, district_id, rooms, construction_period, furnished)`. L'import fait un `upsert_all` sur cet index (`INSERT ... ON CONFLICT DO UPDATE`) : le relancer met à jour les mêmes lignes au lieu de créer des doublons. C'est Postgres qui le garantit, pas du code Ruby.

**Des contraintes en base en plus des validations.** `upsert_all` contourne les validations Rails. Des contraintes `CHECK` (pièces entre 1 et 4, époques connues, `min ≤ ref ≤ max`) protègent quand même les données. Les validations servent les messages d'erreur, les contraintes servent l'intégrité.

**Pagination par année.** L'API refuse `offset + limit > 10 000`, alors que le jeu de données compte 17 920 lignes. Le client pagine donc année par année (2 560 lignes chacune), avec un tri stable (`order_by`) pour que les pages ne se chevauchent pas. Si une année dépassait la limite, le client lèverait une erreur plutôt que de tronquer les données sans prévenir.

**Un connecteur isolé, qui échoue bruyamment.** `Client` ne fait que du HTTP, `Importer` ne fait que de la transformation. Un format inattendu (champ manquant, HTML à la place du JSON, nouvelle époque inconnue) lève une erreur explicite au lieu d'écrire des données fausses.

**Des retries adaptés à l'erreur.**
- Faraday retente les erreurs passagères (timeouts, 429, 5xx) avec un délai qui double à chaque essai, mais jamais les 4xx.
- Le job utilise `retry_on` quand l'API est indisponible et `discard_on` quand son format a changé, puisque retenter ne servirait à rien.
- `sidekiq_options retry: false` évite que Sidekiq retente à son tour un job qu'Active Job a déjà abandonné.

**Pas de transaction autour de l'import.** Elle garderait une connexion à la base ouverte pendant les appels HTTP. Comme l'import est idempotent, un échec en cours de route se rattrape en le relançant.

**La logique métier hors des controllers.** `RentComparison` est un objet Ruby avec ActiveModel : les attributs typés convertissent les paramètres HTTP et les validations produisent les erreurs 422. Les controllers ne s'occupent que du HTTP.

**L'agrégation en SQL.** Les rapports sont calculés par un `GROUP BY` en une seule requête (un test le vérifie), et l'`EXPLAIN` montre que l'index unique est utilisé.

**Les loyers sont fixés par zone, pas par quartier.** En analysant les données, on voit que les 80 quartiers sont regroupés en 14 zones qui partagent exactement les mêmes loyers. D'où le rapport par zone, plus lisible. La table garde la forme du jeu de données source (non normalisée), parce que c'est plus simple à importer et sans risque pour des données en lecture seule. La version normalisée serait une table `zones`, qui porte les loyers, et une table `districts` qui pointe vers sa zone.

**`decimal` pour les montants.** Jamais de `float` pour de l'argent. Les valeurs de l'API passent par une chaîne avant `BigDecimal` pour ne pas garder les erreurs d'arrondi du float.

## Données

« Logement - Encadrement des loyers », [Ville de Paris](https://opendata.paris.fr/explore/dataset/logement-encadrement-des-loyers/), licence ODbL. Années 2019 à 2025.
