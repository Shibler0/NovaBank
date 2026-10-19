-- Exécutées avec les droits de bank_owner ; l'application ne touche pas aux tables.
CREATE PROCEDURE core.sp_transfer(
    p_from bigint, p_to bigint, p_amount numeric, p_label text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
DECLARE
    v_balance numeric;
    v_from_status core.account_status_enum;
    v_to_status core.account_status_enum;
    v_transfer_id bigint;
BEGIN
    IF p_from IS NULL OR p_to IS NULL OR p_from = p_to
       OR p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Virement invalide';
    END IF;

    -- Toujours verrouiller les comptes dans le même ordre.
    PERFORM 1 FROM core.accounts
    WHERE account_id IN (p_from, p_to)
    ORDER BY account_id FOR UPDATE;

    SELECT balance, status INTO v_balance, v_from_status
    FROM core.accounts WHERE account_id = p_from;
    SELECT status INTO v_to_status
    FROM core.accounts WHERE account_id = p_to;

    IF v_from_status IS NULL OR v_to_status IS NULL
       OR v_from_status <> 'ACTIVE' OR v_to_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Compte inexistant ou inactif';
    END IF;
    IF v_balance < p_amount THEN
        RAISE EXCEPTION 'Solde insuffisant';
    END IF;

    INSERT INTO core.transfers (from_account_id, to_account_id, amount, label)
    VALUES (p_from, p_to, p_amount, coalesce(p_label, 'Virement'))
    RETURNING transfer_id INTO v_transfer_id;

    -- Le trigger met à jour les soldes et calcule balance_after.
    INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id)
    VALUES (p_from, 'TRANSFER_OUT', -p_amount, 0, v_transfer_id);

    INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id)
    VALUES (p_to, 'TRANSFER_IN', p_amount, 0, v_transfer_id);
END;
$$;

CREATE PROCEDURE core.sp_open_account(
    p_customer_id bigint, p_iban text, p_type core.account_type_enum,
    INOUT p_account_id bigint DEFAULT NULL
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM core.customers
        WHERE customer_id = p_customer_id AND kyc_status = 'VERIFIED'
    ) THEN
        RAISE EXCEPTION 'Client inexistant ou non vérifié';
    END IF;

    INSERT INTO core.accounts (customer_id, iban, account_type)
    VALUES (p_customer_id, p_iban, p_type)
    RETURNING account_id INTO p_account_id;
END;
$$;

-- Le curseur permet de lire le relevé entre BEGIN et COMMIT.
CREATE PROCEDURE core.sp_statement(
    p_account_id bigint, INOUT p_cursor refcursor DEFAULT 'releve'
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, pg_temp
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM core.accounts WHERE account_id = p_account_id) THEN
        RAISE EXCEPTION 'Compte inexistant';
    END IF;

    OPEN p_cursor FOR
        SELECT tx_id, tx_type, amount, balance_after, created_at
        FROM core.transactions
        WHERE account_id = p_account_id
        ORDER BY created_at, tx_id;
END;
$$;

-- Ne jamais laisser EXECUTE à PUBLIC, uniquement à l'application.
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA core FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE core.sp_transfer(bigint, bigint, numeric, text) TO app_user;
GRANT EXECUTE ON PROCEDURE core.sp_open_account(
    bigint, text, core.account_type_enum, bigint
) TO app_user;
GRANT EXECUTE ON PROCEDURE core.sp_statement(bigint, refcursor) TO app_user;
