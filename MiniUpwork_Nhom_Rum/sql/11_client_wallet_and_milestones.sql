CREATE TABLE miniupwork.client_wallet (
    client_id BIGINT PRIMARY KEY REFERENCES miniupwork.client(user_id) ON DELETE RESTRICT,
    balance NUMERIC(16,2) NOT NULL DEFAULT 0 CHECK (balance >= 0 AND balance <> 'NaN'::numeric)
);

INSERT INTO miniupwork.client_wallet (client_id)
SELECT user_id FROM miniupwork.client;

CREATE TABLE miniupwork.fixed_cancellation (
    contract_id BIGINT PRIMARY KEY REFERENCES miniupwork.fixed_price_contract(contract_id) ON DELETE RESTRICT,
    completed_count INTEGER NOT NULL,
    milestone_count INTEGER NOT NULL,
    rate_percent NUMERIC(5,2) NOT NULL CHECK (rate_percent BETWEEN 0 AND 20),
    already_paid NUMERIC(12,2) NOT NULL CHECK (already_paid >= 0),
    gross_payout NUMERIC(12,2) NOT NULL CHECK (gross_payout >= 0),
    refunded_escrow NUMERIC(12,2) NOT NULL CHECK (refunded_escrow >= 0),
    assessed_penalty NUMERIC(12,2) NOT NULL CHECK (assessed_penalty >= 0),
    withheld_penalty NUMERIC(12,2) NOT NULL CHECK (withheld_penalty = LEAST(gross_payout, assessed_penalty)),
    outstanding_penalty NUMERIC(12,2) GENERATED ALWAYS AS (assessed_penalty - withheld_penalty) STORED,
    cancelled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (completed_count >= 0 AND completed_count < milestone_count)
);
CREATE TRIGGER fixed_cancellation_history BEFORE UPDATE OR DELETE ON miniupwork.fixed_cancellation
FOR EACH ROW EXECUTE FUNCTION miniupwork.protect_history();

-- Only payouts bundled into a cancellation with a deduction are locked against full reversal.
CREATE TABLE miniupwork.fixed_cancellation_payout (
    contract_id BIGINT NOT NULL REFERENCES miniupwork.fixed_cancellation(contract_id) ON DELETE RESTRICT,
    payment_id BIGINT PRIMARY KEY REFERENCES miniupwork.payment_transaction(payment_id) ON DELETE RESTRICT
);
CREATE TRIGGER fixed_cancellation_payout_history BEFORE UPDATE OR DELETE ON miniupwork.fixed_cancellation_payout
FOR EACH ROW EXECUTE FUNCTION miniupwork.protect_history();

CREATE TABLE miniupwork.fixed_cancellation_fee_payment (
    contract_id BIGINT PRIMARY KEY REFERENCES miniupwork.fixed_cancellation(contract_id) ON DELETE RESTRICT,
    paid_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TRIGGER fixed_cancellation_fee_payment_history BEFORE UPDATE OR DELETE ON miniupwork.fixed_cancellation_fee_payment
FOR EACH ROW EXECUTE FUNCTION miniupwork.protect_history();

CREATE TABLE miniupwork.client_wallet_entry (
    entry_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id BIGINT NOT NULL REFERENCES miniupwork.client_wallet(client_id) ON DELETE RESTRICT,
    kind TEXT NOT NULL CHECK (kind IN ('BANK_TOP_UP', 'ESCROW_DEPOSIT', 'ESCROW_REFUND',
                                      'HOURLY_CHARGE', 'REVERSAL', 'CANCELLATION_PENALTY', 'CANCELLATION_FEE_PAYMENT')),
    amount NUMERIC(16,2) NOT NULL CHECK (amount <> 0 AND amount <> 'NaN'::numeric),
    payment_id BIGINT UNIQUE REFERENCES miniupwork.payment_transaction(payment_id) ON DELETE RESTRICT,
    cancellation_id BIGINT REFERENCES miniupwork.fixed_cancellation(contract_id) ON DELETE RESTRICT,
    bank_reference UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (client_id, bank_reference),
    UNIQUE (kind, cancellation_id),
    CHECK ((kind = 'BANK_TOP_UP') = (bank_reference IS NOT NULL)),
    CHECK ((kind IN ('CANCELLATION_PENALTY', 'CANCELLATION_FEE_PAYMENT')) = (cancellation_id IS NOT NULL)),
    CHECK ((kind IN ('ESCROW_DEPOSIT','ESCROW_REFUND','HOURLY_CHARGE','REVERSAL')) = (payment_id IS NOT NULL)),
    CHECK ((kind IN ('ESCROW_DEPOSIT','HOURLY_CHARGE')) = (amount < 0))
);
CREATE INDEX wallet_entries_by_client ON miniupwork.client_wallet_entry(client_id, entry_id DESC);
CREATE TRIGGER wallet_entry_history BEFORE UPDATE OR DELETE ON miniupwork.client_wallet_entry
FOR EACH ROW EXECUTE FUNCTION miniupwork.protect_history();

CREATE FUNCTION miniupwork.open_client_wallet()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    INSERT INTO miniupwork.client_wallet (client_id) VALUES (NEW.user_id);
    RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION miniupwork.open_client_wallet() FROM PUBLIC;
CREATE TRIGGER open_client_wallet AFTER INSERT ON miniupwork.client
FOR EACH ROW EXECUTE FUNCTION miniupwork.open_client_wallet();

CREATE FUNCTION miniupwork.update_wallet_balance()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    UPDATE miniupwork.client_wallet SET balance = balance + NEW.amount
    WHERE client_id = NEW.client_id AND balance + NEW.amount >= 0;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient wallet balance' USING ERRCODE = '23514', CONSTRAINT = 'wallet_insufficient';
    END IF;
    RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION miniupwork.update_wallet_balance() FROM PUBLIC;
CREATE TRIGGER update_wallet_balance AFTER INSERT ON miniupwork.client_wallet_entry
FOR EACH ROW EXECUTE FUNCTION miniupwork.update_wallet_balance();

CREATE FUNCTION miniupwork.bank_top_up(client_key BIGINT, bank_amount NUMERIC, reference UUID)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE entry_key BIGINT; original_amount NUMERIC;
BEGIN
    IF bank_amount IS NULL OR bank_amount <> ROUND(bank_amount, 2)
       OR bank_amount NOT BETWEEN 0.01 AND 9999999999.99 OR reference IS NULL THEN
        RAISE EXCEPTION 'Invalid bank deposit' USING ERRCODE = '23514';
    END IF;
    INSERT INTO miniupwork.client_wallet_entry (client_id, kind, amount, bank_reference)
    VALUES (client_key, 'BANK_TOP_UP', bank_amount, reference)
    ON CONFLICT (client_id, bank_reference) DO NOTHING RETURNING entry_id INTO entry_key;
    IF entry_key IS NULL THEN
        SELECT entry_id, amount INTO entry_key, original_amount FROM miniupwork.client_wallet_entry
        WHERE client_id = client_key AND bank_reference = reference;
        IF original_amount IS DISTINCT FROM bank_amount THEN
            RAISE EXCEPTION 'Bank reference already recorded' USING ERRCODE = '23514', CONSTRAINT = 'bank_reference_conflict';
        END IF;
    END IF;
    RETURN entry_key;
END;
$$;
REVOKE ALL ON FUNCTION miniupwork.bank_top_up(BIGINT, NUMERIC, UUID) FROM PUBLIC;

CREATE FUNCTION miniupwork.post_wallet_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE wallet_client BIGINT; delta NUMERIC;
BEGIN
    IF NEW.status <> 'SUCCEEDED' OR (TG_OP = 'UPDATE' AND OLD.status = 'SUCCEEDED') THEN RETURN NULL; END IF;
    IF NEW.transaction_type IN ('ESCROW_DEPOSIT','HOURLY_CHARGE') THEN
        wallet_client := NEW.payer_id;
        delta := -NEW.amount;
    ELSIF NEW.transaction_type IN ('ESCROW_REFUND','REVERSAL') THEN
        wallet_client := NEW.payee_id;
        delta := NEW.amount;
    ELSE
        RETURN NULL;
    END IF;
    INSERT INTO miniupwork.client_wallet_entry (client_id, kind, amount, payment_id)
    VALUES (wallet_client, NEW.transaction_type, delta, NEW.payment_id);
    RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION miniupwork.post_wallet_payment() FROM PUBLIC;
CREATE TRIGGER post_wallet_payment AFTER INSERT OR UPDATE OF status ON miniupwork.payment_transaction
FOR EACH ROW EXECUTE FUNCTION miniupwork.post_wallet_payment();

CREATE FUNCTION miniupwork.post_cancellation_penalty()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    IF NEW.withheld_penalty > 0 THEN
        INSERT INTO miniupwork.client_wallet_entry (client_id, kind, amount, cancellation_id)
        SELECT j.client_id, 'CANCELLATION_PENALTY', NEW.withheld_penalty, NEW.contract_id
        FROM miniupwork.contract c JOIN miniupwork.proposal p USING (proposal_id)
        JOIN miniupwork.job j USING (job_id) WHERE c.contract_id = NEW.contract_id;
    END IF;
    RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION miniupwork.post_cancellation_penalty() FROM PUBLIC;
CREATE TRIGGER post_cancellation_penalty AFTER INSERT ON miniupwork.fixed_cancellation
FOR EACH ROW EXECUTE FUNCTION miniupwork.post_cancellation_penalty();

CREATE FUNCTION miniupwork.post_cancellation_fee_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    INSERT INTO miniupwork.client_wallet_entry (client_id, kind, amount, cancellation_id)
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
REVOKE ALL ON FUNCTION miniupwork.post_cancellation_fee_payment() FROM PUBLIC;
CREATE TRIGGER post_cancellation_fee_payment AFTER INSERT ON miniupwork.fixed_cancellation_fee_payment
FOR EACH ROW EXECUTE FUNCTION miniupwork.post_cancellation_fee_payment();

CREATE FUNCTION miniupwork.guard_cancellation_payment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.transaction_type = 'REVERSAL' AND NEW.status IN ('PENDING','SUCCEEDED') AND EXISTS (
        SELECT 1 FROM miniupwork.fixed_cancellation_payout WHERE payment_id = NEW.original_payment_id
    ) THEN
        RAISE EXCEPTION 'Payment was included in a net cancellation payout'
            USING ERRCODE = '23514', CONSTRAINT = 'cancellation_payout_reversal';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER protect_cancellation_payment BEFORE INSERT OR UPDATE OF status ON miniupwork.payment_transaction
FOR EACH ROW EXECUTE FUNCTION miniupwork.guard_cancellation_payment();

ALTER TABLE miniupwork.milestone ADD UNIQUE (contract_id, milestone_id);
ALTER TABLE miniupwork.review
    ADD COLUMN milestone_id BIGINT,
    ADD FOREIGN KEY (contract_id, milestone_id) REFERENCES miniupwork.milestone(contract_id, milestone_id) ON DELETE RESTRICT,
    DROP CONSTRAINT review_contract_id_reviewer_id_key;
CREATE UNIQUE INDEX one_contract_review_per_direction ON miniupwork.review(contract_id, reviewer_id) WHERE milestone_id IS NULL;
CREATE UNIQUE INDEX one_milestone_review_per_direction ON miniupwork.review(milestone_id, reviewer_id) WHERE milestone_id IS NOT NULL;

CREATE OR REPLACE FUNCTION miniupwork.guard_review()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE parties RECORD;
BEGIN
    SELECT c.status, c.contract_type, j.client_id, p.freelancer_id INTO parties
    FROM miniupwork.contract c JOIN miniupwork.proposal p USING (proposal_id)
    JOIN miniupwork.job j USING (job_id) WHERE c.contract_id = NEW.contract_id FOR SHARE OF c;
    IF NOT FOUND OR NOT (
        (NEW.reviewer_id, NEW.reviewee_id) = (parties.client_id, parties.freelancer_id)
        OR (NEW.reviewer_id, NEW.reviewee_id) = (parties.freelancer_id, parties.client_id)
    ) OR NOT (
        (parties.contract_type = 'HOURLY' AND NEW.milestone_id IS NULL AND parties.status = 'COMPLETED')
        OR (parties.contract_type = 'FIXED_PRICE' AND EXISTS (
            SELECT 1 FROM miniupwork.milestone WHERE milestone_id = NEW.milestone_id
              AND contract_id = NEW.contract_id AND status = 'RELEASED'
        ))
    ) THEN
        RAISE EXCEPTION 'Review requires an eligible milestone or completed hourly contract'
            USING ERRCODE = '23514', CONSTRAINT = 'review_source';
    END IF;
    RETURN NEW;
END;
$$;
