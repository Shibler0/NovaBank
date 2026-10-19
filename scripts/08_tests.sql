\echo === TESTS NOVABANK (modifications annulees a la fin) ===
BEGIN;

-- Données et soldes cohérents.
DO $$
BEGIN
    IF (SELECT count(*) FROM core.transactions) <> 1000000 THEN
        RAISE EXCEPTION 'Il manque des écritures';
    END IF;
    IF EXISTS (SELECT 1 FROM core.accounts WHERE balance < 0) THEN
        RAISE EXCEPTION 'Solde négatif';
    END IF;
    IF EXISTS (
        SELECT 1 FROM core.transfers v
        LEFT JOIN core.transactions t ON t.transfer_id = v.transfer_id
        GROUP BY v.transfer_id HAVING count(t.tx_id) <> 2
    ) THEN
        RAISE EXCEPTION 'Un virement n a pas deux écritures';
    END IF;
    IF has_table_privilege('app_user', 'core.customers', 'SELECT')
       OR has_table_privilege('support_user', 'core.customers', 'SELECT')
       OR NOT has_table_privilege('support_user', 'core.v_customers_masked', 'SELECT')
       OR NOT has_table_privilege('auditor_user', 'audit.audit_log', 'SELECT')
       OR NOT has_function_privilege('app_user',
               'core.sp_transfer(bigint,bigint,numeric,text)', 'EXECUTE') THEN
        RAISE EXCEPTION 'Mauvais droits';
    END IF;
    RAISE NOTICE 'OK : 1 million d écritures, soldes, virements, permissions';
END;
$$;

-- Cas positif : ouvrir un compte, transférer, lire un relevé.
CALL core.sp_open_account(1, 'FR76TESTNOUVEAU', 'SAVINGS', NULL);
CALL core.sp_transfer(1, 2, 10, 'Test');
CALL core.sp_statement(1, 'releve_test');
FETCH 3 FROM releve_test;

-- Cas négatifs : une contrainte, une vue et le grand livre doivent refuser.
DO $$
DECLARE
    refused boolean;
BEGIN
    refused := false;
    BEGIN
        INSERT INTO core.customers (first_name, last_name, email, phone, birth_date)
        VALUES ('Mineur', 'Test', 'mineur@test.fr', '0600000000', CURRENT_DATE);
    EXCEPTION WHEN check_violation THEN refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'Age non contrôlé'; END IF;

    refused := false;
    BEGIN
        UPDATE core.v_active_accounts SET status = 'CLOSED' WHERE account_id = 3;
    EXCEPTION WHEN SQLSTATE '44000' THEN refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'Vue non protégée'; END IF;

    refused := false;
    BEGIN
        UPDATE core.transactions SET amount = 1 WHERE tx_id = 1;
    EXCEPTION WHEN raise_exception THEN refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'Modification du grand livre acceptée'; END IF;

    refused := false;
    BEGIN
        DELETE FROM core.transactions WHERE tx_id = 1;
    EXCEPTION WHEN raise_exception THEN refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'Suppression du grand livre acceptée'; END IF;

    refused := false;
    BEGIN
        EXECUTE 'TRUNCATE core.transactions';
    EXCEPTION WHEN raise_exception THEN refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'TRUNCATE du grand livre accepté'; END IF;

    refused := false;
    BEGIN
        CALL core.sp_transfer(1, 2, 1000000, 'Impossible');
    EXCEPTION WHEN raise_exception THEN refused := true;
    END;
    IF NOT refused THEN RAISE EXCEPTION 'Virement sans provision accepté'; END IF;

    RAISE NOTICE 'OK : contraintes, vue, historique et provision';
END;
$$;

-- Cas positifs : les deux règles de fraude et le journal d'audit.
CALL core.sp_transfer(1, 2, 1, 'Test 1');
CALL core.sp_transfer(1, 2, 1, 'Test 2');
CALL core.sp_transfer(1, 2, 1, 'Test 3');
CALL core.sp_transfer(1, 2, 1, 'Test 4');
CALL core.sp_transfer(1, 2, 1, 'Test 5');
INSERT INTO core.transactions (account_id, tx_type, amount, balance_after)
VALUES (1, 'WITHDRAWAL', -5000, 0);
UPDATE core.accounts SET status = 'BLOCKED' WHERE account_id = 3;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM core.fraud_alerts WHERE rule_code = 'LARGE_WITHDRAWAL') OR
       NOT EXISTS (SELECT 1 FROM core.fraud_alerts WHERE rule_code = 'FIVE_TRANSFERS_10MIN') THEN
        RAISE EXCEPTION 'Alerte fraude manquante';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM audit.audit_log WHERE table_name = 'core.accounts') THEN
        RAISE EXCEPTION 'Journal d audit manquant';
    END IF;
    RAISE NOTICE 'OK : alertes fraude et audit';
END;
$$;

ROLLBACK;
\echo === FIN DES TESTS : base initiale conservee ===
