-- Comparer les temps et les buffers affichés avant et après l'index.
ANALYZE core.transactions;
\echo === AVANT LES INDEX ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM core.transactions WHERE account_id = 1
ORDER BY created_at DESC LIMIT 10;

CREATE INDEX idx_transactions_account_date
ON core.transactions (account_id, created_at DESC);

CREATE INDEX idx_customers_email_lower ON core.customers (lower(email));
CREATE INDEX idx_accounts_blocked ON core.accounts (account_id)
WHERE status = 'BLOCKED';
CREATE INDEX idx_transactions_date_brin ON core.transactions USING brin (created_at);

ANALYZE core.transactions;
\echo === APRES LES INDEX ===
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM core.transactions WHERE account_id = 1
ORDER BY created_at DESC LIMIT 10;
