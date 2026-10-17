# NovaBank

## Description du Projet
NovaBank Core est un système de gestion de base de données bancaire sous PostgreSQL 18 développé sur une VM Ubuntu. Le projet couvre l'architecture complète : sécurisation du serveur Linux/PostgreSQL, modélisation de schémas complexes, génération d'un million de transactions financières cohérentes, gestion stricte des privilèges (principe du moindre privilège), vues de masquage et d'agrégation, optimisation des performances (indexation ciblée), déclencheurs d'audit et de détection de fraude, ainsi que procédures stockées d'exécution sécurisées.

## Captures d'écran
<img width="979" height="144" alt="Capture d’écran 2026-10-13 à 15 25 31" src="https://github.com/user-attachments/assets/50331390-f275-49e5-aff3-f4f2effb3f73" />
<img width="979" height="144" alt="Capture d’écran 2026-10-13 à 15 14 24" src="https://github.com/user-attachments/assets/c1c82224-0a7c-4c68-a731-494443c5cb0c" />
<img width="1145" height="144" alt="Capture d’écran 2026-10-13 à 15 06 37" src="https://github.com/user-attachments/assets/a89f19a5-98ef-4d89-9b7a-77a0dd046f30" />
<img width="1145" height="374" alt="Capture d’écran 2026-10-13 à 14 57 57" src="https://github.com/user-attachments/assets/1f269ed9-c39c-470b-ac81-6e9a6341207a" />
<img width="1145" height="374" alt="Capture d’écran 2026-10-13 à 14 30 27" src="https://github.com/user-attachments/assets/03810885-efbb-4259-b343-e568c88cb811" />
<img width="771" height="374" alt="Capture d’écran 2026-10-13 à 14 30 12" src="https://github.com/user-attachments/assets/d425f7a7-1f83-4662-bb6d-7b81e936823d" />
<img width="771" height="374" alt="Capture d’écran 2026-10-13 à 14 29 52" src="https://github.com/user-attachments/assets/421958db-a576-400b-bde4-c7c7982277d4" />

## Structure

novabank/
├── 01_setup_server.sh
├── 02_schema_and_data.sql
├── 03_roles_and_permissions.sql
├── 04_views.sql
├── 05_indexes_and_perf.sql
├── 06_triggers.sql
├── 07_procedures.sql
├── master.sh
├── bankdb_backup.dump
└── README.md

## Rôles et Matrice des Droits

Les accès sont strictement régis selon le principe du moindre privilège. L'application `app_user` n'a aucun accès direct en écriture sur les tables de données et doit obligatoirement passer par les procédures stockées.

| Rôle / Groupe | Type | Schémas | Droits sur Tables / Vues | Accès aux Procédures |
| :--- | :--- | :--- | :--- | :--- |
| `bank_owner` | Login | `core`, `audit` | Propriétaire complet (`ALL PRIVILEGES`) | `ALL` |
| `app_user` | Login | `core` | `SELECT` sur `core` & vues | `EXECUTE` (`sp_transfer`) |
| `analysts_group` | Nologin | `core` | `SELECT` sur `accounts`, `transfers`, `transactions`, `fraud_alerts`, `mv_daily_account_summary` | Aucun |
| `support_group` | Nologin | `core` | `SELECT` sur toutes les tables `core` (accès via `v_customers_masked`) | Aucun |
| `auditors_group` | Nologin | `core`, `audit` | `SELECT` sur l'ensemble des tables `core` et `audit.audit_log` | Aucun |

---
