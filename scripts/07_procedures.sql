CREATE OR REPLACE PROCEDURE core.sp_transfer(
    p_from bigint,
    p_to bigint,
    p_amount numeric,
    p_label text
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_bal numeric;
    v_transfer_id bigint;
BEGIN
    SELECT balance INTO v_from_bal FROM core.accounts WHERE account_id = p_from FOR UPDATE;
    
    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION 'Solde insuffisant';
    END IF;

    INSERT INTO core.transfers (from_account_id, to_account_id, amount, label)
    VALUES (p_from, p_to, p_amount, p_label)
    RETURNING transfer_id INTO v_transfer_id;

    UPDATE core.accounts SET balance = balance - p_amount WHERE account_id = p_from;
    UPDATE core.accounts SET balance = balance + p_amount WHERE account_id = p_to;

    INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id)
    VALUES (p_from, 'TRANSFER_OUT', -p_amount, v_from_bal - p_amount, v_transfer_id);

    INSERT INTO core.transactions (account_id, tx_type, amount, balance_after, transfer_id)
    VALUES (p_to, 'TRANSFER_IN', p_amount, (SELECT balance FROM core.accounts WHERE account_id = p_to), v_transfer_id);
END;
$$;

REVOKE ALL ON ALL TABLES IN SCHEMA core FROM app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO app_user;
GRANT EXECUTE ON PROCEDURE core.sp_transfer TO app_user;