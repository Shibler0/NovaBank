CREATE VIEW core.v_customers_masked AS
SELECT 
    customer_id,
    first_name,
    last_name,
    '***@' || split_part(email, '@', 2) AS email,
    phone,
    birth_date
FROM core.customers;

CREATE VIEW core.v_active_accounts AS
SELECT * FROM core.accounts WHERE status = 'ACTIVE';

CREATE OR REPLACE FUNCTION core.fn_insert_active_account()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO core.accounts (customer_id, iban, account_type, balance)
    VALUES (NEW.customer_id, NEW.iban, NEW.account_type, COALESCE(NEW.balance, 0.00));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_insert_active_account
INSTEAD OF INSERT ON core.v_active_accounts
FOR EACH ROW EXECUTE FUNCTION core.fn_insert_active_account();

CREATE MATERIALIZED VIEW core.mv_daily_summary AS
SELECT account_id, COUNT(*) AS total_tx, SUM(amount) AS total_amount
FROM core.transactions
GROUP BY account_id;

CREATE UNIQUE INDEX idx_mv_daily_summary ON core.mv_daily_summary (account_id);