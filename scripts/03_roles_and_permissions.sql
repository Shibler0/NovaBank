REVOKE ALL ON SCHEMA public FROM PUBLIC;

CREATE ROLE app_user WITH LOGIN PASSWORD 'AppPassword123!';
CREATE ROLE analysts_group NOLOGIN;
CREATE ROLE support_group NOLOGIN;
CREATE ROLE auditors_group NOLOGIN;

GRANT USAGE ON SCHEMA core TO app_user, analysts_group, support_group, auditors_group;
GRANT USAGE ON SCHEMA audit TO auditors_group;

GRANT SELECT ON ALL TABLES IN SCHEMA core TO app_user, support_group, auditors_group;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO auditors_group;

GRANT SELECT ON core.accounts, core.transfers, core.transactions, core.fraud_alerts TO analysts_group;