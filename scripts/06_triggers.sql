CREATE OR REPLACE FUNCTION core.fn_detect_fraud()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tx_type = 'WITHDRAWAL' AND ABS(NEW.amount) >= 5000 THEN
        INSERT INTO core.fraud_alerts (account_id, tx_id, rule_code)
        VALUES (NEW.account_id, NEW.tx_id, 'LARGE_WITHDRAWAL');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_detect_fraud
AFTER INSERT ON core.transactions
FOR EACH ROW EXECUTE FUNCTION core.fn_detect_fraud();

CREATE OR REPLACE FUNCTION audit.fn_log_audit()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit.audit_log (table_name, operation, old_data, new_data)
    VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD), to_jsonb(NEW));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_customers
AFTER INSERT OR UPDATE OR DELETE ON core.customers
FOR EACH ROW EXECUTE FUNCTION audit.fn_log_audit();