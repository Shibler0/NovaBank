-- Le support voit uniquement les informations masquées.
CREATE VIEW core.v_customers_masked WITH (security_barrier = true) AS
SELECT customer_id, left(first_name, 1) || '.' AS first_name,
       left(last_name, 1) || '.' AS last_name,
       '***@' || split_part(email, '@', 2) AS email,
       '********' || right(phone, 2) AS phone
FROM core.customers;

-- Vue modifiable : CHECK OPTION refuse les changements hors du filtre.
CREATE VIEW core.v_active_accounts AS
SELECT account_id, customer_id, iban, account_type, balance, status, opened_at
FROM core.accounts
WHERE status = 'ACTIVE'
WITH LOCAL CHECK OPTION;

-- Vue enregistrée par jour et par compte.
CREATE MATERIALIZED VIEW core.mv_daily_summary AS
SELECT account_id, created_at::date AS day,
       count(*) AS total_tx, sum(amount) AS total_amount
FROM core.transactions
GROUP BY account_id, created_at::date;

CREATE UNIQUE INDEX idx_mv_daily_summary ON core.mv_daily_summary (account_id, day);

GRANT SELECT ON core.v_customers_masked TO support_group;
GRANT SELECT ON core.v_active_accounts TO analysts_group, auditors_group;
GRANT SELECT ON core.mv_daily_summary TO analysts_group, auditors_group;
