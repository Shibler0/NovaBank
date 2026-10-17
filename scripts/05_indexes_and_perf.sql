CREATE INDEX idx_transactions_account ON core.transactions (account_id, created_at DESC);
CREATE INDEX idx_transfers_from ON core.transfers (from_account_id);
CREATE INDEX idx_transfers_to ON core.transfers (to_account_id);
CREATE INDEX idx_customers_name ON core.customers (last_name, first_name);

ANALYZE core.customers, core.accounts, core.transfers, core.transactions;

EXPLAIN ANALYZE
SELECT * FROM core.transactions WHERE account_id = 1 ORDER BY created_at DESC LIMIT 10;