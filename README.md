# cicd-fil-rouge — TaskFlow API

API de gestion de tâches développée avec **FastAPI**, support du fil rouge CI/CD.

Fonctionnalités : création, complétion et recherche de tâches, suppression protégée par token, endpoint de santé, et injection de pannes configurable pour les exercices de fiabilité.

Ce dépôt est un fork public de [`9m7fjfpv9k-cyber/cicd-fil-rouge`](https://github.com/9m7fjfpv9k-cyber/cicd-fil-rouge).

## Équipe

| Membre | Compte GitHub | Rôle |
|---|---|---|
| Denilsson | [@DENFR18](https://github.com/DENFR18) | Propriétaire du fork, code owner |
| Illies | [@IB432](https://github.com/IB432) | Collaborateur (write), code owner |

## Structure du projet

```
.
├── .github/
│   ├── CODEOWNERS
│   └── workflows/
│       ├── ci.yml                # Lint + tests sur chaque PR
│       └── publish-images.yml    # Publication des images TaskFlow
├── app/                          # Code de l'API FastAPI
├── tests/                        # Tests pytest (conftest.py + suites)
├── docs/images/                  # Captures du lab
├── Dockerfile
├── pyproject.toml
└── README.md
```

## Configuration

L'application se configure par variables d'environnement. Les trois premières sont figées au build de l'image via `ARG`.

| Variable | Défaut | Description |
|---|---|---|
| `APP_VERSION` | `dev` | Version exposée par l'API |
| `FAILURE_RATE` | `0` | Taux de requêtes en échec simulé (injection de pannes) |
| `LATENCY_MS` | `0` | Latence ajoutée à chaque requête, en millisecondes |
| `DB_PATH` | `/tmp/taskflow.db` | Chemin de la base SQLite |

## Lancer le projet

### En local

```bash
python -m pip install -e .
python -m pip install pytest httpx ruff
# À VÉRIFIER : adapter le module selon le CMD du Dockerfile
python -m uvicorn app.main:app --reload --port 8000
```

### Avec Docker

```bash
docker build -t taskflow:dev .
docker run --rm -p 8000:8000 taskflow:dev
```

Avec injection de pannes :

```bash
docker build -t taskflow:faulty --build-arg FAILURE_RATE=0.2 --build-arg LATENCY_MS=300 .
```

## Protection de la branche `main`

### Ruleset `protect-main`

| Règle | Effet |
|---|---|
| Pull request obligatoire | Aucun push direct sur `main` |
| 1 approbation requise | Une PR doit être approuvée par un collaborateur avec droits d'écriture |
| Review des code owners | Toute modification de `.github/workflows/` doit être approuvée par un code owner (voir [`.github/CODEOWNERS`](.github/CODEOWNERS)) |
| Status checks requis | Les jobs `lint` et `test` doivent être verts (voir [Pipeline CI](#pipeline-ci)) |
| Block force pushes | Réécriture de l'historique interdite |
| Restrict deletions | Suppression de `main` interdite |

### Mise en place

1. **Fork public et binôme.** Le dépôt `9m7fjfpv9k-cyber/cicd-fil-rouge` a été forké en public, cloné en local, et IB432 a été invité comme collaborateur avec droits d'écriture.

   ![Invitation du binôme](docs/images/collaborateur-invite.png)

2. **Ruleset sur `main`.** Création du ruleset `protect-main` ciblant la branche par défaut : PR obligatoire, 1 approbation, force push et suppression interdits.

   ![Règles du ruleset protect-main](docs/images/ruleset-protect-main.png)

3. **Push direct refusé.** Une tentative de `git push` directement sur `main` est rejetée par GitHub :

```
   remote: - Changes must be made through a pull request.
    ! [remote rejected] main -> main (push declined due to repository rule violations)
```

   ![Push direct refusé](docs/images/push-refuse.png)

4. **Branche `feat/equipe-readme` et PR #1.** La modification passe par une PR vers `main`. Tant que le binôme n'a pas approuvé, la PR affiche « Review required » et le merge est bloqué :

   ![PR bloquée sans review](docs/images/pr-review-required.png)

   Une fois la PR approuvée par IB432, le merge devient possible :

   ![PR approuvée](docs/images/pr-approuvee.png)

5. **CODEOWNERS.** Le fichier `.github/CODEOWNERS` désigne DENFR18 et IB432 comme propriétaires de `.github/workflows/`, et l'option *Require review from Code Owners* est activée dans le ruleset.

### Workflow de contribution

1. Créer une branche depuis `main` à jour (`feat/...`, `fix/...`, `docs/...`).
2. Pousser la branche et ouvrir une PR **vers `main` du fork** (attention au « base repository »).
3. Attendre que `lint` et `test` soient verts.
4. Faire approuver par le binôme.
5. Merger.

## Pipeline CI

Le workflow [`.github/workflows/ci.yml`](.github/workflows/ci.yml) garantit qu'**aucun code n'arrive sur `main` sans lint ni tests**.

### Déclenchement

| Événement | Branche | Objectif |
|---|---|---|
| `pull_request` | vers `main` | Valider le code avant le merge |
| `push` | `main` | Revalider `main` après chaque merge |

Le workflow tourne sur `ubuntu-latest` avec Python 3.12, et ses permissions sont limitées à `contents: read`.

### Jobs

Les deux jobs n'ont aucune dépendance entre eux, ils s'exécutent donc **en parallèle**.

| Job | Outil | Commande | Ce qu'il vérifie |
|---|---|---|---|
| `lint` | [ruff](https://docs.astral.sh/ruff/) | `ruff check .` | Analyse statique de tout le code Python : erreurs de syntaxe, imports inutilisés, variables non définies et règles de style (par exemple W292, retour à la ligne manquant en fin de fichier). Le job échoue dès qu'une règle est violée. |
| `test` | [pytest](https://docs.pytest.org/) | `pytest -v` | Exécution de la suite de tests de l'API TaskFlow (13 tests dans `tests/` : santé, CRUD des tâches, recherche, token requis pour la suppression, injection de pannes). La configuration est lue dans `pyproject.toml`. Le job échoue si un seul test échoue. |

Le job `test` installe `pytest`, `httpx` et les dépendances du projet. `httpx` est nécessaire au `TestClient` de FastAPI utilisé dans `tests/conftest.py`.

### Mise en place

1. **Activation de GitHub Actions** sur le fork, depuis l'onglet Actions. Les workflows sont désactivés par défaut sur un fork.
2. **Branche `feat/ci`** : ajout de `.github/workflows/ci.yml` avec les jobs `lint` et `test`.
3. **PR #2 vers `main`** :
   - Run #1 ❌ : `test` échouait au chargement de `tests/conftest.py` (`RuntimeError: The starlette.testclient module requires the httpx package`).
   - Correctif : ajout de `httpx` à l'installation des dépendances du job `test`.
   - Run #2 ✅ : `lint` et `test` verts, PR approuvée par le binôme puis mergée.
   - Run #3 ✅ : le workflow se relance automatiquement sur `main` après le merge (déclencheur `push`).

   ![Historique des runs CI](docs/images/actions-runs.png)

   ![CI verte sur main après le merge](docs/images/ci-main-success.png)

4. **Ruleset : status checks obligatoires.** Une fois que `lint` et `test` ont tourné au moins une fois, ils sont ajoutés comme checks requis dans `protect-main` (option *Require status checks to pass*). Une PR ne peut plus être mergée si l'un des deux échoue.

   ![Status checks requis dans le ruleset](docs/images/ruleset-status-checks.png)

5. **Branche `fix/casse-test`** : vérification que le blocage fonctionne (voir ci-dessous).

### Démonstration : merge bloqué par un test en échec

La branche `fix/casse-test` ajoute volontairement un test faux :

```python
def test_casse():
    assert 1 + 1 == 3
```

Résultat sur la PR #3 :

- `lint` ✅ : le code respecte les règles ruff.
- `test` ❌ : `1 failed, 12 passed` (`AssertionError` sur `test_casse`).
- Le bouton **Merge pull request** est grisé : le check requis `test` est en échec.

![PR bloquée par le check test](docs/images/pr-bloquee.png)

![Log pytest du job test](docs/images/log-test-casse.png)

La PR a été fermée sans être mergée.

### Lancer les vérifications en local

```bash
python -m pip install ruff pytest httpx
python -m ruff check .
python -m pytest -v
```