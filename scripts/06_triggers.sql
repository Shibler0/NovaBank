-- Une écriture modifie le solde de façon atomique, avec verrouillage de la ligne.
CREATE FUNCTION core.fn_apply_transaction() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE core.accounts
       SET balance = balance + NEW.amount
     WHERE account_id = NEW.account_id
       AND status = 'ACTIVE'
       AND balance + NEW.amount >= 0
    RETURNING balance INTO NEW.balance_after;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Compte inactif, inexistant ou solde insuffisant';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_apply_transaction
BEFORE INSERT ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_apply_transaction();

-- Le grand livre ne peut plus être modifié ou vidé.
CREATE FUNCTION core.fn_block_history() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Le grand livre est immuable';
END;
$$;

CREATE TRIGGER trg_block_update_delete
BEFORE UPDATE OR DELETE ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_block_history();

CREATE TRIGGER trg_block_truncate
BEFORE TRUNCATE ON core.transactions
FOR EACH STATEMENT EXECUTE FUNCTION core.fn_block_history();

-- Une vérification différée garantit les deux écritures d'un virement.
CREATE FUNCTION core.fn_check_transfer_entries() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_id bigint;
    v_total integer;
    v_valid integer;
BEGIN
    v_id := NEW.transfer_id;
    SELECT count(*),
           count(*) FILTER (WHERE
               (t.tx_type = 'TRANSFER_OUT' AND t.account_id = v.from_account_id
                    AND t.amount = -v.amount)
            OR (t.tx_type = 'TRANSFER_IN' AND t.account_id = v.to_account_id
                    AND t.amount = v.amount))
    INTO v_total, v_valid
    FROM core.transfers v
    LEFT JOIN core.transactions t ON t.transfer_id = v.transfer_id
    WHERE v.transfer_id = v_id;

    IF v_total <> 2 OR v_valid <> 2 THEN
        RAISE EXCEPTION 'Le virement % doit avoir exactement 2 écritures', v_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_check_transfer
AFTER INSERT ON core.transfers
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION core.fn_check_transfer_entries();

CREATE CONSTRAINT TRIGGER trg_check_transfer_entries
AFTER INSERT ON core.transactions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW WHEN (NEW.transfer_id IS NOT NULL)
EXECUTE FUNCTION core.fn_check_transfer_entries();

-- Fraude : retrait >= 5 000.
CREATE FUNCTION core.fn_detect_large_withdrawal() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.tx_type = 'WITHDRAWAL' AND -NEW.amount >= 5000 THEN
        INSERT INTO core.fraud_alerts (account_id, tx_id, rule_code)
        VALUES (NEW.account_id, NEW.tx_id, 'LARGE_WITHDRAWAL');
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_large_withdrawal
AFTER INSERT ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_detect_large_withdrawal();

-- Fraude : cinq virements sortants sur dix minutes.
CREATE FUNCTION core.fn_detect_fast_transfers() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF (SELECT count(*)
        FROM core.transfers
        WHERE from_account_id = NEW.from_account_id
          AND created_at BETWEEN NEW.created_at - INTERVAL '10 minutes' AND NEW.created_at) >= 5
    THEN
        INSERT INTO core.fraud_alerts (account_id, rule_code)
        VALUES (NEW.from_account_id, 'FIVE_TRANSFERS_10MIN');
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_fast_transfers
AFTER INSERT ON core.transfers
FOR EACH ROW EXECUTE FUNCTION core.fn_detect_fast_transfers();

-- Journal : qui a fait quoi, avant et après.
CREATE FUNCTION audit.fn_log_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO audit.audit_log (table_name, operation, old_data, new_data, db_user)
    VALUES (TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME, TG_OP,
            CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE to_jsonb(OLD) END,
            CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE to_jsonb(NEW) END,
            session_user);
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_audit_customers AFTER INSERT OR UPDATE OR DELETE ON core.customers
FOR EACH ROW EXECUTE FUNCTION audit.fn_log_change();

CREATE TRIGGER trg_audit_accounts AFTER INSERT OR UPDATE OR DELETE ON core.accounts
FOR EACH ROW EXECUTE FUNCTION audit.fn_log_change();

CREATE TRIGGER trg_audit_transfers AFTER INSERT OR UPDATE OR DELETE ON core.transfers
FOR EACH ROW EXECUTE FUNCTION audit.fn_log_change();

CREATE TRIGGER trg_audit_alerts AFTER INSERT OR UPDATE OR DELETE ON core.fraud_alerts
FOR EACH ROW EXECUTE FUNCTION audit.fn_log_change();
