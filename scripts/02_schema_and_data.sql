CREATE ROLE bank_owner WITH LOGIN PASSWORD 'ChangeMe123!';

CREATE SCHEMA core AUTHORIZATION bank_owner;
CREATE SCHEMA audit AUTHORIZATION bank_owner;

CREATE TYPE core.kyc_status_enum AS ENUM ('PENDING', 'VERIFIED', 'REJECTED');
CREATE TYPE core.risk_level_enum AS ENUM ('LOW', 'MEDIUM', 'HIGH');
CREATE TYPE core.account_type_enum AS ENUM ('CHECKING', 'SAVINGS');
CREATE TYPE core.account_status_enum AS ENUM ('ACTIVE', 'BLOCKED', 'CLOSED');
CREATE TYPE core.tx_type_enum AS ENUM ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER_IN', 'TRANSFER_OUT');
CREATE TYPE core.alert_status_enum AS ENUM ('NEW', 'INVESTIGATING', 'DISMISSED', 'CONFIRMED');

CREATE TABLE core.customers (
    customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name text NOT NULL,
    last_name text NOT NULL,
    email text NOT NULL UNIQUE,
    phone text NOT NULL,
    birth_date date NOT NULL,
    kyc_status core.kyc_status_enum NOT NULL DEFAULT 'PENDING',
    risk_level core.risk_level_enum NOT NULL DEFAULT 'LOW',
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT ck_customers_email CHECK (email LIKE '%@%.%'),
    CONSTRAINT ck_customers_adult CHECK (birth_date <= CURRENT_DATE - INTERVAL '18 years')
);

CREATE TABLE core.accounts (
    account_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES core.customers(customer_id),
    iban text NOT NULL UNIQUE,
    account_type core.account_type_enum NOT NULL,
    balance numeric(14,2) NOT NULL DEFAULT 0.00,
    status core.account_status_enum NOT NULL DEFAULT 'ACTIVE',
    opened_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT ck_accounts_balance CHECK (balance >= 0.00)
);

CREATE TABLE core.transfers (
    transfer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    from_account_id bigint NOT NULL REFERENCES core.accounts(account_id),
    to_account_id bigint NOT NULL REFERENCES core.accounts(account_id),
    amount numeric(14,2) NOT NULL,
    label text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT ck_transfers_amount CHECK (amount > 0.00),
    CONSTRAINT ck_transfers_accounts CHECK (from_account_id <> to_account_id)
);

CREATE TABLE core.transactions (
    tx_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES core.accounts(account_id),
    tx_type core.tx_type_enum NOT NULL,
    amount numeric(14,2) NOT NULL,
    balance_after numeric(14,2) NOT NULL,
    transfer_id bigint REFERENCES core.transfers(transfer_id),
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT ck_transactions_balance CHECK (balance_after >= 0.00)
);

CREATE TABLE core.fraud_alerts (
    alert_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint NOT NULL REFERENCES core.accounts(account_id),
    tx_id bigint REFERENCES core.transactions(tx_id),
    rule_code text NOT NULL,
    status core.alert_status_enum NOT NULL DEFAULT 'NEW',
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE audit.audit_log (
    log_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name text NOT NULL,
    operation text NOT NULL,
    old_data jsonb,
    new_data jsonb,
    db_user text NOT NULL DEFAULT CURRENT_USER,
    changed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

INSERT INTO core.customers (first_name, last_name, email, phone, birth_date, kyc_status)
SELECT 
    'Client_' || g,
    'Nom_' || g,
    'user' || g || '@novabank.fr',
    '0600000000',
    DATE '1990-01-01',
    'VERIFIED'
FROM generate_series(1, 10000) g;

INSERT INTO core.accounts (customer_id, iban, account_type, balance)
SELECT 
    customer_id,
    'FR76' || lpad(customer_id::text, 10, '0') || '01',
    'CHECKING',
    0.00
FROM core.customers;

INSERT INTO core.accounts (customer_id, iban, account_type, balance)
SELECT 
    customer_id,
    'FR76' || lpad(customer_id::text, 10, '0') || '02',
    'SAVINGS',
    0.00
FROM core.customers;

CREATE TEMP TABLE temp_transfers AS
SELECT 
    g AS transfer_id,
    1 + (g % 20000) AS from_acc,
    1 + ((g + 1) % 20000) AS to_acc,
    50.00::numeric(14,2) AS amount,
    TIMESTAMPTZ '2025-01-02' + (g || ' seconds')::interval AS created_at
FROM generate_series(1, 480000) g;

INSERT INTO core.transfers (from_account_id, to_account_id, amount, label, created_at)
SELECT from_acc, to_acc, amount, 'Virement', created_at
FROM temp_transfers;

CREATE TEMP TABLE temp_ops AS
SELECT account_id, 'DEPOSIT'::core.tx_type_enum AS tx_type, 10000.00::numeric(14,2) AS amount, NULL::bigint AS transfer_id, TIMESTAMPTZ '2025-01-01' AS created_at
FROM core.accounts
UNION ALL
SELECT from_acc, 'TRANSFER_OUT', -amount, transfer_id, created_at FROM temp_transfers
UNION ALL
SELECT to_acc, 'TRANSFER_IN', amount, transfer_id, created_at FROM temp_transfers;

INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id, created_at)
SELECT 
    account_id,
    tx_type,
    amount,
    SUM(amount) OVER (PARTITION BY account_id ORDER BY created_at, tx_type) AS balance_after,
    transfer_id,
    created_at
FROM temp_ops;

UPDATE core.accounts a
SET balance = t.balance_after
FROM (
    SELECT DISTINCT ON (account_id) account_id, balance_after
    FROM core.transactions
    ORDER BY account_id, created_at DESC
) t
WHERE a.account_id = t.account_id;