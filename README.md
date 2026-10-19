# NovaBank Core

Projet SQL avancé (PostgreSQL, Linux et Bash). La base contient 6 tables : clients, comptes, virements, écritures, alertes et audit. Les scripts créent **1 000 000 d'écritures** et protègent les soldes et l'historique.

## Préparation

- VM Ubuntu Server avec PostgreSQL (guide : version 18), SSH et Git.
- Deux cartes réseau sur la VM : NAT et host-only, avec une adresse fixe.
- Le script utilise `192.168.51.10` (VM) et `192.168.51.0/24` (réseau privé). Adapter ces valeurs si besoin.
- Aucun Docker et aucun mot de passe dans les fichiers du dépôt.

Depuis la VM, dans le dossier du dépôt :

```bash
sudo bash scripts/master.sh
```

Le script installe PostgreSQL, demande confirmation avant de supprimer `bankdb`, recrée les rôles et les données, exécute les tests et vérifie la restauration d'une sauvegarde. **Attention : les anciennes données de bankdb sont supprimées.**

Pour utiliser une autre adresse IP ou un autre sous-réseau :

```bash
sudo DB_HOST_IP=192.168.51.10 DB_SUBNET=192.168.51.0/24 bash scripts/master.sh
```

## Mots de passe

Les rôles sont créés **sans mot de passe**. Les définir manuellement sur la VM après l'installation :

```bash
sudo -u postgres psql
\password bank_owner
\password app_user
\password analyst_user
\password support_user
\password auditor_user
\q
```

Ne jamais publier ces mots de passe ou le fichier `~/.pgpass`. Si des mots de passe ont été publiés dans d'anciens commits, il faut les changer : la PR n'efface pas l'historique Git.

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `01_setup_server.sh` | PostgreSQL, pg_hba.conf et pare-feu |
| `02_schema_and_data.sql` | 6 tables et 1 million d'écritures |
| `03_roles_and_permissions.sql` | 4 profils et utilisateurs |
| `04_views.sql` | Vue masquée, modifiable, matérialisée |
| `05_indexes_and_perf.sql` | 4 index et EXPLAIN avant/après |
| `06_triggers.sql` | Soldes, immutabilité, fraude, audit |
| `07_procedures.sql` | Virement, ouverture, relevé |
| `08_tests.sql` | Tests automatiques et annulation des changements |
| `09_backup_restore.sh` | pg_dump, pg_restore, comparaison des lignes |
| `master.sh` | Reconstruit le projet dans l'ordre |

## Relations

- `core.customers` → `core.accounts` (1 client, plusieurs comptes)
- `core.accounts` → `core.transfers` (compte source et destination)
- `core.transfers` → `core.transactions` (2 écritures par virement)
- `core.accounts` → `core.transactions` et `core.fraud_alerts`
- `core.transactions` → `core.fraud_alerts`
- `audit.audit_log` garde les anciennes et nouvelles valeurs importantes.

## Matrice des droits

| Rôle | Accès |
| --- | --- |
| `bank_owner` | Propriétaire des objets |
| `app_user` | Exécute les 3 procédures, sans accès direct aux tables |
| `analyst_user` | Lit comptes, virements, écritures, alertes et vues de synthèse |
| `support_user` | Lit uniquement `v_customers_masked` |
| `auditor_user` | Lit les tables et les journaux d'audit |

Les 3 derniers utilisateurs appartiennent aux groupes `analysts_group`, `support_group` et `auditors_group`.

## Vérifications et captures à rendre

Le script `master.sh` lance `08_tests.sql` (tous les changements de test sont annulés) et `09_backup_restore.sh`. On peut aussi les exécuter séparément :

```bash
sudo -u postgres psql -v ON_ERROR_STOP=1 -d bankdb < scripts/08_tests.sql
sudo bash scripts/09_backup_restore.sh
```

Les captures utiles pour le rendu : connexion SSH, `ufw status`, `pg_hba_file_rules`, les 6 tables, le nombre d'écritures, refus d'accès aux emails, `EXPLAIN` avant/après, triggers, procédures, et la restauration.

Test manuel des permissions :

```sql
SET ROLE support_user;
SELECT * FROM core.v_customers_masked LIMIT 2; -- autorisé
SELECT * FROM core.customers LIMIT 2;          -- refusé
RESET ROLE;
```

Test manuel de concurrence : ouvrir deux consoles `psql` et lancer en même temps `CALL core.sp_transfer(1, 2, 6000, 'test');`. Une seule doit réussir si le compte possède 10 000. Vérifier ensuite que le solde n'est pas négatif. Faire ce test sur une installation de démonstration (ou dans deux transactions annulées).

La vue matérialisée peut être actualisée avec :

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY core.mv_daily_summary;
```

Le fichier local `bankdb_backup.dump` est ignoré par Git.

## Captures existantes

Les captures de la première version sont dans l'historique du README. Ajouter les nouvelles captures de validation avant le rendu.

## Usage de l'IA

Une IA a aidé à revoir les scripts SQL et Bash, les droits, les transactions concurrentes, les triggers et les tests. Les commandes doivent être comprises et expliquées lors de l'évaluation. Aucun bonus n'est implémenté.
