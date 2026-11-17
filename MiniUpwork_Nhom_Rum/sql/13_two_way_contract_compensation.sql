-- Historical settlements were initiated by freelancers. Their recorded payments
-- remain intact; new settlements also support cancellations by clients.
ALTER TABLE miniupwork.fixed_cancellation
    ADD COLUMN initiator_role TEXT NOT NULL DEFAULT 'FREELANCER' CHECK (initiator_role IN ('CLIENT','FREELANCER')),
    ADD COLUMN wallet_penalty NUMERIC(12,2) NOT NULL DEFAULT 0,
    DROP CONSTRAINT fixed_cancellation_check,
    DROP CONSTRAINT fixed_cancellation_check1,
    DROP COLUMN outstanding_penalty;

ALTER TABLE miniupwork.fixed_cancellation
    ADD COLUMN outstanding_penalty NUMERIC(12,2)
        GENERATED ALWAYS AS (assessed_penalty - withheld_penalty - wallet_penalty) STORED,
    ADD CHECK (milestone_count > 0 AND completed_count BETWEEN 0 AND milestone_count),
    ADD CHECK (withheld_penalty = CASE WHEN initiator_role = 'CLIENT' THEN 0 ELSE LEAST(gross_payout, assessed_penalty) END),
    ADD CHECK (wallet_penalty BETWEEN 0 AND assessed_penalty - withheld_penalty),
    ADD CHECK (initiator_role <> 'CLIENT' OR rate_percent = CASE WHEN completed_count = 0 THEN 20 ELSE 0 END);

ALTER TABLE miniupwork.user_wallet_entry
    DROP CONSTRAINT user_wallet_entry_check1,
    ADD CHECK (
        kind IN ('REVERSAL','CANCELLATION_PENALTY','CANCELLATION_FEE_PAYMENT')
        OR (kind IN ('ESCROW_DEPOSIT','HOURLY_CHARGE')) = (amount < 0)
    );

CREATE OR REPLACE FUNCTION miniupwork.bank_top_up(client_key BIGINT, bank_amount NUMERIC, reference UUID)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE entry_key BIGINT; original_amount NUMERIC;
BEGIN
    IF bank_amount IS NULL OR bank_amount <> ROUND(bank_amount, 2)
       OR bank_amount NOT BETWEEN 0.01 AND 9999999999.99 OR reference IS NULL THEN
        RAISE EXCEPTION 'Invalid bank deposit' USING ERRCODE = '23514';
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

CREATE FUNCTION miniupwork.transfer_contract_compensation(target_contract BIGINT, initiator TEXT, total NUMERIC, entry_kind TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    PERFORM miniupwork.lock_contract_wallets(target_contract);
    INSERT INTO miniupwork.user_wallet_entry (user_id, kind, amount, cancellation_id)
    SELECT party.user_id, entry_kind, party.amount, target_contract
    FROM miniupwork.contract c JOIN miniupwork.proposal p USING (proposal_id)
    JOIN miniupwork.job j USING (job_id)
    CROSS JOIN LATERAL (VALUES
        (j.client_id, CASE WHEN initiator = 'CLIENT' THEN -total ELSE total END),
        (p.freelancer_id, CASE WHEN initiator = 'FREELANCER' THEN -total ELSE total END)
    ) AS party(user_id, amount)
    WHERE c.contract_id = target_contract;
END;
$$;
REVOKE ALL ON FUNCTION miniupwork.transfer_contract_compensation(BIGINT, TEXT, NUMERIC, TEXT) FROM PUBLIC;

CREATE OR REPLACE FUNCTION miniupwork.post_cancellation_penalty()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
    IF NEW.withheld_penalty + NEW.wallet_penalty > 0 THEN
        PERFORM miniupwork.transfer_contract_compensation(
            NEW.contract_id, NEW.initiator_role, NEW.withheld_penalty + NEW.wallet_penalty, 'CANCELLATION_PENALTY'
        );
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.post_cancellation_fee_payment()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE remaining NUMERIC; initiator TEXT;
BEGIN
    SELECT outstanding_penalty, initiator_role INTO remaining, initiator
    FROM miniupwork.fixed_cancellation WHERE contract_id = NEW.contract_id;
    IF remaining IS NULL OR remaining <= 0 THEN
        RAISE EXCEPTION 'There is no remaining cancellation fee' USING ERRCODE = '23514';
    END IF;
    PERFORM miniupwork.transfer_contract_compensation(NEW.contract_id, initiator, remaining, 'CANCELLATION_FEE_PAYMENT');
    RETURN NULL;
END;
$$;

CREATE FUNCTION miniupwork.require_fixed_cancellation()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.contract_type = 'FIXED_PRICE' AND OLD.status IN ('ACTIVE','PAUSED') AND NEW.status = 'TERMINATED'
       AND NOT EXISTS (SELECT 1 FROM miniupwork.fixed_cancellation WHERE contract_id = NEW.contract_id) THEN
        RAISE EXCEPTION 'Signed fixed-price contracts require a cancellation settlement'
            USING ERRCODE = '23514', CONSTRAINT = 'fixed_cancellation_required';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER fixed_cancellation_required BEFORE UPDATE OF status ON miniupwork.contract
FOR EACH ROW EXECUTE FUNCTION miniupwork.require_fixed_cancellation();
