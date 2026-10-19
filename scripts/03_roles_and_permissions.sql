-- Les groupes définissent les permissions ; les utilisateurs s'y rattachent.
CREATE ROLE app_user LOGIN;
CREATE ROLE analysts_group NOLOGIN;
CREATE ROLE support_group NOLOGIN;
CREATE ROLE auditors_group NOLOGIN;
CREATE ROLE analyst_user LOGIN IN ROLE analysts_group;
CREATE ROLE support_user LOGIN IN ROLE support_group;
CREATE ROLE auditor_user LOGIN IN ROLE auditors_group;

-- Aucun mot de passe n'est stocké dans Git : utiliser \\password dans psql.
REVOKE ALL ON DATABASE bankdb FROM PUBLIC;
GRANT CONNECT ON DATABASE bankdb TO app_user, analysts_group, support_group, auditors_group;

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA core, audit FROM PUBLIC;
GRANT USAGE ON SCHEMA core TO app_user, analysts_group, support_group, auditors_group;
GRANT USAGE ON SCHEMA audit TO auditors_group;

-- Pas de lecture directe de customers pour le support, ni de tables pour l'app.
GRANT SELECT ON core.accounts, core.transfers, core.transactions, core.fraud_alerts
TO analysts_group;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO auditors_group;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO auditors_group;

-- Supprime l'accès EXECUTE accordé par défaut à PUBLIC sur les futures fonctions.
ALTER DEFAULT PRIVILEGES FOR ROLE bank_owner REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
