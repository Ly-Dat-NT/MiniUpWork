ALTER TABLE miniupwork.client_wallet RENAME TO user_wallet;
ALTER TABLE miniupwork.user_wallet RENAME COLUMN client_id TO user_id;
ALTER TABLE miniupwork.user_wallet
    DROP CONSTRAINT client_wallet_client_id_fkey,
    ADD FOREIGN KEY (user_id) REFERENCES miniupwork.app_user(user_id) ON DELETE RESTRICT;

ALTER TABLE miniupwork.client_wallet_entry RENAME TO user_wallet_entry;
ALTER TABLE miniupwork.user_wallet_entry RENAME COLUMN client_id TO user_id;
ALTER TABLE miniupwork.user_wallet_entry
    DROP CONSTRAINT client_wallet_entry_payment_id_key,
    DROP CONSTRAINT client_wallet_entry_kind_cancellation_id_key,
    DROP CONSTRAINT client_wallet_entry_kind_check,
    DROP CONSTRAINT client_wallet_entry_check2,
    DROP CONSTRAINT client_wallet_entry_check3,
    ADD UNIQUE (payment_id, user_id),
    ADD UNIQUE (kind, cancellation_id, user_id),
    ADD CHECK (kind IN ('BANK_TOP_UP', 'ESCROW_DEPOSIT', 'ESCROW_REFUND', 'ESCROW_RELEASE', 'HOURLY_CHARGE',
                        'HOURLY_PAYOUT', 'REVERSAL', 'CANCELLATION_PENALTY', 'CANCELLATION_FEE_PAYMENT')),
    ADD CHECK ((kind IN ('ESCROW_DEPOSIT', 'ESCROW_REFUND', 'ESCROW_RELEASE', 'HOURLY_CHARGE',
                         'HOURLY_PAYOUT', 'REVERSAL')) = (payment_id IS NOT NULL)),
    ADD CHECK (
        kind IN ('REVERSAL','CANCELLATION_PENALTY')
        OR (kind IN ('ESCROW_DEPOSIT','HOURLY_CHARGE')) = (amount < 0)
    );
DROP INDEX miniupwork.wallet_entries_by_client;
CREATE INDEX user_wallet_entries_recent ON miniupwork.user_wallet_entry(user_id, created_at DESC, entry_id DESC);

INSERT INTO miniupwork.user_wallet (user_id)
SELECT user_id FROM miniupwork.app_user ON CONFLICT (user_id) DO NOTHING;

DROP TRIGGER open_client_wallet ON miniupwork.client;
DROP FUNCTION miniupwork.open_client_wallet();

CREATE FUNCTION miniupwork.open_user_wallet()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    INSERT INTO miniupwork.user_wallet (user_id) VALUES (NEW.user_id);
    RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION miniupwork.open_user_wallet() FROM PUBLIC;
CREATE TRIGGER open_user_wallet AFTER INSERT ON miniupwork.app_user
FOR EACH ROW EXECUTE FUNCTION miniupwork.open_user_wallet();

CREATE OR REPLACE FUNCTION miniupwork.update_wallet_balance()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    UPDATE miniupwork.user_wallet SET balance = balance + NEW.amount
    WHERE user_id = NEW.user_id AND balance + NEW.amount >= 0;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient wallet balance' USING ERRCODE = '23514', CONSTRAINT = 'wallet_insufficient';
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.bank_top_up(client_key BIGINT, bank_amount NUMERIC, reference UUID)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE entry_key BIGINT; original_amount NUMERIC;
BEGIN
    IF bank_amount IS NULL OR bank_amount <> ROUND(bank_amount, 2)
       OR bank_amount NOT BETWEEN 0.01 AND 9999999999.99 OR reference IS NULL THEN
        RAISE EXCEPTION 'Invalid bank deposit' USING ERRCODE = '23514';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM miniupwork.client WHERE user_id = client_key) THEN
        RAISE EXCEPTION 'Bank deposits require a client profile' USING ERRCODE = '23514';
    END IF;
    INSERT INTO miniupwork.user_wallet_entry (user_id, kind, amount, bank_reference)
    VALUES (client_key, 'BANK_TOP_UP', bank_amount, reference)
    ON CONFLICT (user_id, bank_reference) DO NOTHING RETURNING entry_id INTO entry_key;
    IF entry_key IS NULL THEN
        SELECT entry_id, amount INTO entry_key, original_amount FROM miniupwork.user_wallet_entry
        WHERE user_id = client_key AND bank_reference = reference;
        IF original_amount IS DISTINCT FROM bank_amount THEN
            RAISE EXCEPTION 'Bank reference already recorded' USING ERRCODE = '23514', CONSTRAINT = 'bank_reference_conflict';
        END IF;
    END IF;
    RETURN entry_key;
END;
$$;

-- Lock both accounts in the same order whenever a settlement moves both balances.
CREATE FUNCTION miniupwork.lock_contract_wallets(target_contract BIGINT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    PERFORM w.user_id
    FROM miniupwork.contract c JOIN miniupwork.proposal p USING (proposal_id)
    JOIN miniupwork.job j USING (job_id)
    JOIN miniupwork.user_wallet w ON w.user_id IN (j.client_id, p.freelancer_id)
    WHERE c.contract_id = target_contract ORDER BY w.user_id FOR NO KEY UPDATE OF w;
END;
$$;
REVOKE ALL ON FUNCTION miniupwork.lock_contract_wallets(BIGINT) FROM PUBLIC;

CREATE OR REPLACE FUNCTION miniupwork.post_wallet_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    IF NEW.status <> 'SUCCEEDED' OR (TG_OP = 'UPDATE' AND OLD.status = 'SUCCEEDED') THEN RETURN NULL; END IF;
    IF NEW.transaction_type IN ('HOURLY_PAYOUT', 'REVERSAL') THEN
        PERFORM miniupwork.lock_contract_wallets(NEW.contract_id);
    END IF;
    IF NEW.transaction_type IN ('ESCROW_DEPOSIT', 'HOURLY_CHARGE', 'REVERSAL') THEN
        INSERT INTO miniupwork.user_wallet_entry (user_id, kind, amount, payment_id)
        VALUES (NEW.payer_id, NEW.transaction_type, -NEW.amount, NEW.payment_id);
    END IF;
    IF NEW.transaction_type IN ('ESCROW_REFUND', 'ESCROW_RELEASE', 'HOURLY_PAYOUT', 'REVERSAL') THEN
        INSERT INTO miniupwork.user_wallet_entry (user_id, kind, amount, payment_id)
        VALUES (NEW.payee_id, NEW.transaction_type, NEW.amount, NEW.payment_id);
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.post_cancellation_penalty()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    IF NEW.withheld_penalty > 0 THEN
        PERFORM miniupwork.lock_contract_wallets(NEW.contract_id);
        INSERT INTO miniupwork.user_wallet_entry (user_id, kind, amount, cancellation_id)
        SELECT side.user_id, 'CANCELLATION_PENALTY', side.amount, NEW.contract_id
        FROM miniupwork.contract c JOIN miniupwork.proposal p USING (proposal_id)
        JOIN miniupwork.job j USING (job_id)
        CROSS JOIN LATERAL (VALUES (j.client_id, NEW.withheld_penalty),
                                   (p.freelancer_id, -NEW.withheld_penalty)) AS side(user_id, amount)
        WHERE c.contract_id = NEW.contract_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.post_cancellation_fee_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    INSERT INTO miniupwork.user_wallet_entry (user_id, kind, amount, cancellation_id)
    SELECT j.client_id, 'CANCELLATION_FEE_PAYMENT', s.outstanding_penalty, s.contract_id
    FROM miniupwork.fixed_cancellation s JOIN miniupwork.contract c USING (contract_id)
    JOIN miniupwork.proposal p USING (proposal_id) JOIN miniupwork.job j USING (job_id)
    WHERE s.contract_id = NEW.contract_id AND s.outstanding_penalty > 0;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'There is no remaining cancellation fee' USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$$;

-- The old wallet records the client side already. Add the historical freelancer
-- side from settled transactions, with no new charges against client balances.
INSERT INTO miniupwork.user_wallet_entry (user_id, kind, amount, payment_id, created_at)
SELECT p.payee_id, p.transaction_type, p.amount, p.payment_id, COALESCE(e.released_at, p.created_at)
FROM miniupwork.payment_transaction p LEFT JOIN miniupwork.escrow_funding e ON e.funding_id = p.escrow_funding_id
WHERE p.status = 'SUCCEEDED' AND p.transaction_type IN ('ESCROW_RELEASE', 'HOURLY_PAYOUT')
ORDER BY p.created_at, p.payment_id;

INSERT INTO miniupwork.user_wallet_entry (user_id, kind, amount, payment_id, created_at)
SELECT payer_id, 'REVERSAL', -amount, payment_id, created_at
FROM miniupwork.payment_transaction WHERE status = 'SUCCEEDED' AND transaction_type = 'REVERSAL'
ORDER BY created_at, payment_id;

INSERT INTO miniupwork.user_wallet_entry (user_id, kind, amount, cancellation_id, created_at)
SELECT p.freelancer_id, 'CANCELLATION_PENALTY', -s.withheld_penalty, s.contract_id, s.cancelled_at
FROM miniupwork.fixed_cancellation s JOIN miniupwork.contract c USING (contract_id)
JOIN miniupwork.proposal p USING (proposal_id)
WHERE s.withheld_penalty > 0
ORDER BY s.cancelled_at, s.contract_id;

-- Let existing read-only queries and the previous server keep working during rollout.
CREATE VIEW miniupwork.client_wallet AS
SELECT w.user_id AS client_id, w.balance FROM miniupwork.user_wallet w JOIN miniupwork.client c USING (user_id);

CREATE VIEW miniupwork.client_wallet_entry AS
SELECT e.entry_id, e.user_id AS client_id, e.kind, e.amount, e.payment_id, e.cancellation_id, e.bank_reference, e.created_at
FROM miniupwork.user_wallet_entry e JOIN miniupwork.client c USING (user_id);
