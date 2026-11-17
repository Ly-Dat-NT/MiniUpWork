-- Repair billing against the one-invoice-per-week rule and extend financial history.
ALTER TABLE miniupwork.weekly_invoice
    DROP CONSTRAINT weekly_invoice_status_check,
    ADD CONSTRAINT weekly_invoice_status_check
        CHECK (status IN ('DRAFT', 'ISSUED', 'APPROVED', 'DISPUTED', 'PAID', 'VOID', 'NO_CHARGE'));

ALTER TABLE miniupwork.time_entry
    ADD COLUMN carryover_week DATE,
    ADD COLUMN billing_week DATE GENERATED ALWAYS AS
        (COALESCE(carryover_week, date_trunc('week', start_at AT TIME ZONE 'UTC')::date)) STORED,
    ADD CONSTRAINT time_entry_carryover_week CHECK (
        carryover_week IS NULL OR (
            extract(isodow FROM carryover_week) = 1
            AND carryover_week > date_trunc('week', start_at AT TIME ZONE 'UTC')::date
        )
    );

-- Preserve original dates and already-issued invoices. Move only previously stranded
-- eligible entries to the first later week that can still accept billable time.
ALTER TABLE miniupwork.time_entry DISABLE TRIGGER time_entry_guard;
UPDATE miniupwork.time_entry t
SET carryover_week = (
    SELECT t.billing_week + offset_week * 7
    FROM generate_series(1, (
        SELECT count(*)::integer + 1 FROM miniupwork.weekly_invoice i WHERE i.contract_id = t.contract_id
    )) AS weeks(offset_week)
    WHERE NOT EXISTS (
        SELECT 1 FROM miniupwork.weekly_invoice i WHERE i.contract_id = t.contract_id
          AND i.period_start = t.billing_week + offset_week * 7 AND i.status NOT IN ('DRAFT', 'VOID')
    )
    ORDER BY offset_week LIMIT 1
)
WHERE t.invoice_id IS NULL AND t.eligibility_status = 'ELIGIBLE'
  AND EXISTS (SELECT 1 FROM miniupwork.contract c WHERE c.contract_id = t.contract_id AND c.status IN ('ACTIVE', 'PAUSED'))
  AND EXISTS (
      SELECT 1 FROM miniupwork.weekly_invoice i WHERE i.contract_id = t.contract_id
        AND i.period_start = t.billing_week AND i.status NOT IN ('DRAFT', 'VOID')
  );
ALTER TABLE miniupwork.time_entry ENABLE TRIGGER time_entry_guard;
CREATE INDEX time_entry_unbilled_week ON miniupwork.time_entry(contract_id, billing_week)
    WHERE invoice_id IS NULL AND eligibility_status = 'ELIGIBLE';

ALTER TABLE miniupwork.weekly_invoice DISABLE TRIGGER invoice_guard;
UPDATE miniupwork.weekly_invoice i SET status = 'VOID'
WHERE i.status = 'DRAFT' AND NOT EXISTS (SELECT 1 FROM miniupwork.invoice_total(i.invoice_id));
UPDATE miniupwork.weekly_invoice i SET status = 'NO_CHARGE'
WHERE i.status = 'APPROVED' AND (SELECT amount FROM miniupwork.invoice_total(i.invoice_id)) = 0;
ALTER TABLE miniupwork.weekly_invoice ENABLE TRIGGER invoice_guard;

CREATE OR REPLACE FUNCTION miniupwork.guard_time_entry()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE live_status TEXT; invoice_row RECORD; week_begin TIMESTAMPTZ; max_hours SMALLINT; logged_seconds NUMERIC; target_week DATE;
BEGIN
    IF TG_OP = 'UPDATE' AND (NEW.entry_id, NEW.contract_id) <> (OLD.entry_id, OLD.contract_id) THEN
        RAISE EXCEPTION 'Time entry identity is immutable' USING ERRCODE = '23514';
    END IF;
    IF (TG_OP = 'INSERT' AND NEW.carryover_week IS NOT NULL)
       OR (TG_OP = 'UPDATE' AND NEW.carryover_week IS DISTINCT FROM OLD.carryover_week) THEN
        RAISE EXCEPTION 'Historical billing carryover is immutable' USING ERRCODE = '23514';
    END IF;
    SELECT c.status, h.weekly_limit INTO live_status, max_hours
    FROM miniupwork.contract c JOIN miniupwork.hourly_contract h USING (contract_id)
    WHERE c.contract_id = NEW.contract_id FOR UPDATE OF c;
    IF live_status IS DISTINCT FROM 'ACTIVE' THEN
        RAISE EXCEPTION 'Time can only be recorded on an active hourly contract' USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'UPDATE' AND EXISTS (SELECT 1 FROM miniupwork.weekly_invoice WHERE invoice_id = OLD.invoice_id AND status <> 'DRAFT') THEN
        RAISE EXCEPTION 'Issued time entries are immutable' USING ERRCODE = '23514';
    END IF;
    week_begin := date_trunc('week', NEW.start_at, 'UTC');
    IF NEW.end_at > week_begin + INTERVAL '168 hours' OR NEW.start_at >= NEW.end_at THEN
        RAISE EXCEPTION 'Time entry must be inside one billing week' USING ERRCODE = '23514';
    END IF;
    target_week := COALESCE(NEW.carryover_week, (week_begin AT TIME ZONE 'UTC')::date);
    IF NEW.invoice_id IS NULL AND NEW.eligibility_status = 'ELIGIBLE' AND EXISTS (
        SELECT 1 FROM miniupwork.weekly_invoice i
        WHERE i.contract_id = NEW.contract_id AND i.period_start = target_week
          AND i.status NOT IN ('DRAFT', 'VOID')
    ) THEN
        RAISE EXCEPTION 'This billing week already has an issued invoice'
            USING ERRCODE = '23514', CONSTRAINT = 'billing_week_closed';
    END IF;
    IF NEW.invoice_id IS NOT NULL THEN
        SELECT contract_id, period_start, status INTO invoice_row FROM miniupwork.weekly_invoice WHERE invoice_id = NEW.invoice_id;
        IF NOT FOUND OR invoice_row.contract_id <> NEW.contract_id OR invoice_row.status <> 'DRAFT'
           OR invoice_row.period_start <> target_week THEN
            RAISE EXCEPTION 'Time entry must belong to the draft invoice of the same week and contract' USING ERRCODE = '23514';
        END IF;
    END IF;
    IF EXISTS (SELECT 1 FROM miniupwork.time_entry e WHERE e.contract_id = NEW.contract_id
        AND e.entry_id <> NEW.entry_id AND e.start_at < NEW.end_at AND NEW.start_at < e.end_at) THEN
        RAISE EXCEPTION 'Time entries overlap' USING ERRCODE = '23514', CONSTRAINT = 'time_entry_overlap';
    END IF;
    SELECT COALESCE(SUM(EXTRACT(epoch FROM end_at - start_at)), 0) INTO logged_seconds
    FROM miniupwork.time_entry WHERE contract_id = NEW.contract_id AND entry_id <> NEW.entry_id
      AND start_at >= week_begin AND start_at < week_begin + INTERVAL '168 hours';
    IF logged_seconds + EXTRACT(epoch FROM NEW.end_at - NEW.start_at) > max_hours * 3600 THEN
        RAISE EXCEPTION 'Weekly hour limit exceeded' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.guard_contract()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE job_kind TEXT; accepted TEXT; planned NUMERIC; agreed NUMERIC;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT j.job_type, p.status INTO job_kind, accepted
        FROM miniupwork.proposal p JOIN miniupwork.job j USING (job_id)
        WHERE p.proposal_id = NEW.proposal_id FOR SHARE OF p;
        IF accepted IS DISTINCT FROM 'ACCEPTED' OR job_kind IS DISTINCT FROM NEW.contract_type
           OR NEW.status <> 'DRAFT' THEN
            RAISE EXCEPTION 'Contract needs an accepted proposal of the same type and starts as DRAFT'
                USING ERRCODE = '23514', CONSTRAINT = 'contract_origin';
        END IF;
        RETURN NEW;
    END IF;
    IF (NEW.contract_id, NEW.proposal_id, NEW.contract_type, NEW.start_date)
       IS DISTINCT FROM (OLD.contract_id, OLD.proposal_id, OLD.contract_type, OLD.start_date) THEN
        RAISE EXCEPTION 'Contract origin is immutable' USING ERRCODE = '23514';
    END IF;
    IF NEW.status = OLD.status THEN
        IF NEW.end_date IS DISTINCT FROM OLD.end_date THEN
            RAISE EXCEPTION 'End date changes only with closure' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
    END IF;
    IF NOT ((OLD.status = 'DRAFT' AND NEW.status IN ('ACTIVE', 'TERMINATED'))
        OR (OLD.status = 'ACTIVE' AND NEW.status IN ('PAUSED', 'COMPLETED', 'TERMINATED'))
        OR (OLD.status = 'PAUSED' AND NEW.status IN ('ACTIVE', 'TERMINATED'))) THEN
        RAISE EXCEPTION 'Invalid contract transition' USING ERRCODE = '23514';
    END IF;
    IF NEW.status = 'ACTIVE' AND NEW.contract_type = 'FIXED_PRICE' THEN
        SELECT agreed_amount INTO agreed FROM miniupwork.fixed_price_contract WHERE contract_id = NEW.contract_id;
        SELECT SUM(amount) INTO planned FROM miniupwork.milestone WHERE contract_id = NEW.contract_id;
        IF planned IS NULL OR planned IS DISTINCT FROM agreed THEN
            RAISE EXCEPTION 'Milestones must add up to the agreed amount' USING ERRCODE = '23514';
        END IF;
    END IF;
    IF NEW.status = 'COMPLETED' AND (
        EXISTS (SELECT 1 FROM miniupwork.milestone WHERE contract_id = NEW.contract_id AND status NOT IN ('RELEASED', 'CANCELLED'))
        OR (NEW.contract_type = 'FIXED_PRICE' AND NOT EXISTS (
            SELECT 1 FROM miniupwork.milestone WHERE contract_id = NEW.contract_id AND status = 'RELEASED'
        ))
        OR EXISTS (SELECT 1 FROM miniupwork.weekly_invoice WHERE contract_id = NEW.contract_id
                   AND status NOT IN ('PAID', 'NO_CHARGE', 'VOID'))
        OR EXISTS (SELECT 1 FROM miniupwork.time_entry WHERE contract_id = NEW.contract_id AND invoice_id IS NULL
                   AND eligibility_status = 'ELIGIBLE')
    ) THEN
        RAISE EXCEPTION 'Settle all work before completion'
            USING ERRCODE = '23514', CONSTRAINT = 'contract_unsettled_work';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.guard_work_state()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE live_status TEXT; billed_amount NUMERIC;
BEGIN
    SELECT status INTO live_status FROM miniupwork.contract WHERE contract_id = NEW.contract_id FOR UPDATE;
    IF TG_TABLE_NAME = 'milestone' THEN
        IF TG_OP = 'INSERT' THEN
            IF live_status IS DISTINCT FROM 'DRAFT' OR NEW.status <> 'PLANNED' THEN
                RAISE EXCEPTION 'Plan milestones before activation' USING ERRCODE = '23514';
            END IF;
        ELSE
            IF (NEW.milestone_id, NEW.contract_id, NEW.sequence_no, NEW.amount)
               IS DISTINCT FROM (OLD.milestone_id, OLD.contract_id, OLD.sequence_no, OLD.amount)
               OR (OLD.status IN ('RELEASED', 'CANCELLED') AND NEW IS DISTINCT FROM OLD) THEN
                RAISE EXCEPTION 'Milestone identity, pricing and terminal history are fixed' USING ERRCODE = '23514';
            END IF;
            IF NEW.status <> OLD.status AND (live_status <> 'ACTIVE' OR NOT (
                (OLD.status IN ('PLANNED', 'REFUNDED') AND NEW.status = 'FUNDED' AND EXISTS
                    (SELECT 1 FROM miniupwork.escrow_funding WHERE milestone_id = NEW.milestone_id AND status = 'FUNDED'))
                OR (OLD.status = 'PLANNED' AND NEW.status = 'CANCELLED' AND NOT EXISTS
                    (SELECT 1 FROM miniupwork.escrow_funding WHERE milestone_id = NEW.milestone_id AND status IN ('PENDING','FUNDED')))
                OR (OLD.status = 'FUNDED' AND NEW.status = 'SUBMITTED')
                OR (OLD.status = 'SUBMITTED' AND NEW.status IN ('FUNDED', 'APPROVED'))
                OR (OLD.status = 'FUNDED' AND NEW.status = 'REFUNDED'
                    AND EXISTS (SELECT 1 FROM miniupwork.escrow_funding WHERE milestone_id = NEW.milestone_id AND status = 'REFUNDED')
                    AND NOT EXISTS (SELECT 1 FROM miniupwork.escrow_funding WHERE milestone_id = NEW.milestone_id AND status IN ('PENDING','FUNDED')))
                OR (OLD.status = 'APPROVED' AND NEW.status = 'RELEASED' AND EXISTS
                    (SELECT 1 FROM miniupwork.payment_transaction p JOIN miniupwork.escrow_funding e ON e.funding_id = p.escrow_funding_id
                     WHERE e.milestone_id = NEW.milestone_id AND p.transaction_type = 'ESCROW_RELEASE' AND p.status = 'SUCCEEDED'))
            )) THEN RAISE EXCEPTION 'Invalid milestone transition' USING ERRCODE = '23514'; END IF;
        END IF;
    ELSE
        IF live_status <> 'ACTIVE' THEN RAISE EXCEPTION 'Invoice requires active contract' USING ERRCODE = '23514'; END IF;
        IF TG_OP = 'INSERT' THEN
            IF NEW.status <> 'DRAFT' THEN RAISE EXCEPTION 'Invoice starts as DRAFT' USING ERRCODE = '23514'; END IF;
        ELSE
            IF (NEW.invoice_id, NEW.contract_id, NEW.period_start) IS DISTINCT FROM (OLD.invoice_id, OLD.contract_id, OLD.period_start) THEN
                RAISE EXCEPTION 'Invoice key and week are immutable' USING ERRCODE = '23514';
            END IF;
            IF NEW.status = OLD.status THEN RETURN NEW; END IF;
            SELECT amount INTO billed_amount FROM miniupwork.invoice_total(NEW.invoice_id);
            IF NOT (
                (OLD.status = 'DRAFT' AND NEW.status = 'ISSUED' AND billed_amount IS NOT NULL AND NOT EXISTS (
                    SELECT 1 FROM miniupwork.time_entry e WHERE e.contract_id = NEW.contract_id
                      AND e.billing_week = NEW.period_start AND e.eligibility_status = 'ELIGIBLE' AND e.invoice_id IS NULL
                ))
                OR (OLD.status = 'DRAFT' AND NEW.status = 'VOID' AND billed_amount IS NULL)
                OR (OLD.status IN ('DISPUTED', 'VOID') AND NEW.status = 'DRAFT')
                OR (OLD.status = 'ISSUED' AND NEW.status = 'DISPUTED')
                OR (OLD.status = 'ISSUED' AND NEW.status = 'APPROVED' AND COALESCE(billed_amount, -1) > 0)
                OR (OLD.status = 'ISSUED' AND NEW.status = 'NO_CHARGE' AND COALESCE(billed_amount, -1) = 0)
                OR (OLD.status = 'APPROVED' AND NEW.status = 'PAID' AND EXISTS (
                    SELECT 1 FROM miniupwork.payment_transaction WHERE invoice_id = NEW.invoice_id
                      AND transaction_type = 'HOURLY_CHARGE' AND status = 'SUCCEEDED'
                ))
            ) THEN
                RAISE EXCEPTION 'Invalid invoice transition'
                    USING ERRCODE = '23514', CONSTRAINT = 'invoice_invalid_transition';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE FUNCTION miniupwork.void_empty_draft()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE miniupwork.weekly_invoice i SET status = 'VOID'
    WHERE i.invoice_id = OLD.invoice_id AND i.status = 'DRAFT'
      AND NOT EXISTS (SELECT 1 FROM miniupwork.time_entry e WHERE e.invoice_id = i.invoice_id);
    RETURN NULL;
END;
$$;

CREATE TRIGGER invoice_void_after_exclusion AFTER UPDATE OF invoice_id ON miniupwork.time_entry
FOR EACH ROW WHEN (OLD.invoice_id IS NOT NULL AND NEW.invoice_id IS NULL)
EXECUTE FUNCTION miniupwork.void_empty_draft();

CREATE FUNCTION miniupwork.check_invoice_entries()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM miniupwork.weekly_invoice i WHERE i.invoice_id = NEW.invoice_id AND i.status <> 'VOID')
       AND NOT EXISTS (SELECT 1 FROM miniupwork.time_entry e WHERE e.invoice_id = NEW.invoice_id AND e.eligibility_status = 'ELIGIBLE') THEN
        RAISE EXCEPTION 'An invoice requires an eligible time entry'
            USING ERRCODE = '23514', CONSTRAINT = 'invoice_requires_hours';
    END IF;
    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER invoice_entries_required AFTER INSERT OR UPDATE ON miniupwork.weekly_invoice
DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION miniupwork.check_invoice_entries();

-- Extra ledger rows record completed settlement events generated by the database.
-- Escrow deposits represent held amounts, and a payout records the same settled hourly charge.
ALTER TABLE miniupwork.payment_transaction
    DROP CONSTRAINT payment_transaction_transaction_type_check,
    DROP CONSTRAINT payment_transaction_check3,
    ADD CONSTRAINT payment_transaction_transaction_type_check CHECK (transaction_type IN (
        'ESCROW_DEPOSIT', 'ESCROW_REFUND', 'ESCROW_RELEASE', 'HOURLY_CHARGE', 'HOURLY_PAYOUT', 'REVERSAL'
    )),
    ADD CONSTRAINT payment_type_matches_source CHECK (
        transaction_type = 'REVERSAL'
        OR (transaction_type IN ('ESCROW_DEPOSIT', 'ESCROW_REFUND', 'ESCROW_RELEASE')) = (escrow_funding_id IS NOT NULL)
    ),
    ADD CONSTRAINT settlement_event_final CHECK (
        transaction_type NOT IN ('ESCROW_DEPOSIT', 'ESCROW_REFUND', 'HOURLY_PAYOUT') OR status = 'SUCCEEDED'
    );

CREATE UNIQUE INDEX one_ledger_deposit_or_refund ON miniupwork.payment_transaction(escrow_funding_id, transaction_type)
    WHERE transaction_type IN ('ESCROW_DEPOSIT', 'ESCROW_REFUND');
CREATE UNIQUE INDEX one_hourly_payout ON miniupwork.payment_transaction(invoice_id)
    WHERE transaction_type = 'HOURLY_PAYOUT';

-- The existing source timestamps and completed charges identify historical events.
ALTER TABLE miniupwork.payment_transaction DISABLE TRIGGER payment_guard;
INSERT INTO miniupwork.payment_transaction
    (contract_id, payer_id, payee_id, escrow_funding_id, amount, currency_code, transaction_type, status, created_at)
SELECT m.contract_id,
       CASE WHEN event.kind = 'ESCROW_DEPOSIT' THEN j.client_id ELSE p.freelancer_id END,
       CASE WHEN event.kind = 'ESCROW_DEPOSIT' THEN p.freelancer_id ELSE j.client_id END,
       e.funding_id, e.funded_amount, e.currency_code, event.kind, 'SUCCEEDED', event.occurred_at
FROM miniupwork.escrow_funding e JOIN miniupwork.milestone m USING (milestone_id)
JOIN miniupwork.contract c USING (contract_id) JOIN miniupwork.proposal p USING (proposal_id)
JOIN miniupwork.job j USING (job_id)
CROSS JOIN LATERAL (VALUES
    ('ESCROW_DEPOSIT', e.funded_at),
    ('ESCROW_REFUND', CASE WHEN e.status = 'REFUNDED' THEN e.settled_at END)
) AS event(kind, occurred_at)
WHERE event.occurred_at IS NOT NULL
ORDER BY event.occurred_at, e.funding_id;

INSERT INTO miniupwork.payment_transaction
    (contract_id, payer_id, payee_id, invoice_id, amount, currency_code, transaction_type, status, created_at)
SELECT contract_id, payer_id, payee_id, invoice_id, amount, currency_code, 'HOURLY_PAYOUT', 'SUCCEEDED', created_at
FROM miniupwork.payment_transaction
WHERE transaction_type = 'HOURLY_CHARGE' AND status = 'SUCCEEDED'
ORDER BY payment_id;
ALTER TABLE miniupwork.payment_transaction ENABLE TRIGGER payment_guard;

CREATE OR REPLACE FUNCTION miniupwork.guard_payment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE parties RECORD; original RECORD; expected NUMERIC;
BEGIN
    SELECT c.status, j.client_id, p.freelancer_id INTO parties
    FROM miniupwork.contract c JOIN miniupwork.proposal p USING (proposal_id)
    JOIN miniupwork.job j USING (job_id) WHERE c.contract_id = NEW.contract_id FOR UPDATE OF c;
    IF NOT FOUND THEN RAISE EXCEPTION 'Unknown contract' USING ERRCODE = '23503'; END IF;
    IF TG_OP = 'INSERT' AND NEW.transaction_type IN ('ESCROW_DEPOSIT', 'ESCROW_REFUND', 'HOURLY_PAYOUT') THEN
        IF pg_trigger_depth() < 2 OR NEW.status <> 'SUCCEEDED' THEN
            RAISE EXCEPTION 'This financial event can only be recorded by settlement'
                USING ERRCODE = '23514', CONSTRAINT = 'settlement_generated_only';
        END IF;
        RETURN NEW;
    END IF;
    IF TG_OP = 'INSERT' AND NEW.status <> 'PENDING' THEN
        RAISE EXCEPTION 'Payment starts as pending' USING ERRCODE = '23514';
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status <> 'PENDING' OR NEW.status NOT IN ('SUCCEEDED', 'FAILED')
           OR (to_jsonb(NEW) - 'status') IS DISTINCT FROM (to_jsonb(OLD) - 'status') THEN
            RAISE EXCEPTION 'Only a pending payment can record its final result' USING ERRCODE = '23514';
        END IF;
        IF NEW.status = 'FAILED' THEN RETURN NEW; END IF;
    END IF;
    IF NEW.transaction_type = 'REVERSAL' THEN
        SELECT * INTO original FROM miniupwork.payment_transaction WHERE payment_id = NEW.original_payment_id;
        IF NOT FOUND OR original.status <> 'SUCCEEDED' OR original.transaction_type NOT IN ('ESCROW_RELEASE', 'HOURLY_CHARGE') OR original.contract_id <> NEW.contract_id
           OR (original.payee_id, original.payer_id, original.amount, original.escrow_funding_id, original.invoice_id)
              IS DISTINCT FROM (NEW.payer_id, NEW.payee_id, NEW.amount, NEW.escrow_funding_id, NEW.invoice_id) THEN
            RAISE EXCEPTION 'Reversal must compensate one original payment in full' USING ERRCODE = '23514';
        END IF;
        RETURN NEW;
    END IF;
    IF parties.status <> 'ACTIVE' OR (NEW.payer_id, NEW.payee_id) <> (parties.client_id, parties.freelancer_id) THEN
        RAISE EXCEPTION 'Payment requires the two parties of an active contract' USING ERRCODE = '23514';
    END IF;
    IF NEW.transaction_type = 'ESCROW_RELEASE' THEN
        SELECT e.funded_amount INTO expected FROM miniupwork.escrow_funding e JOIN miniupwork.milestone m USING (milestone_id)
        WHERE e.funding_id = NEW.escrow_funding_id AND m.contract_id = NEW.contract_id
          AND m.status = 'APPROVED' AND e.status = 'FUNDED';
    ELSE
        SELECT total.amount INTO expected FROM miniupwork.weekly_invoice i
        CROSS JOIN LATERAL miniupwork.invoice_total(i.invoice_id) AS total
        WHERE i.invoice_id = NEW.invoice_id AND i.contract_id = NEW.contract_id AND i.status = 'APPROVED';
    END IF;
    IF expected IS NULL OR expected IS DISTINCT FROM NEW.amount THEN
        RAISE EXCEPTION 'Payment source is invalid, settled, or its amount differs' USING ERRCODE = '23514', CONSTRAINT = 'payment_source';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.sync_funding_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status IN ('FUNDED', 'REFUNDED') AND NEW.status <> OLD.status THEN
        UPDATE miniupwork.milestone SET status = NEW.status WHERE milestone_id = NEW.milestone_id;
        INSERT INTO miniupwork.payment_transaction
            (contract_id, payer_id, payee_id, escrow_funding_id, amount, currency_code, transaction_type, status)
        SELECT m.contract_id,
               CASE WHEN NEW.status = 'FUNDED' THEN j.client_id ELSE p.freelancer_id END,
               CASE WHEN NEW.status = 'FUNDED' THEN p.freelancer_id ELSE j.client_id END,
               NEW.funding_id, NEW.funded_amount, NEW.currency_code,
               CASE WHEN NEW.status = 'FUNDED' THEN 'ESCROW_DEPOSIT' ELSE 'ESCROW_REFUND' END, 'SUCCEEDED'
        FROM miniupwork.milestone m JOIN miniupwork.contract c USING (contract_id)
        JOIN miniupwork.proposal p USING (proposal_id) JOIN miniupwork.job j USING (job_id)
        WHERE m.milestone_id = NEW.milestone_id;
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.mark_settled()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.transaction_type = 'ESCROW_RELEASE' THEN
        UPDATE miniupwork.escrow_funding SET status = 'RELEASED' WHERE funding_id = NEW.escrow_funding_id;
        UPDATE miniupwork.milestone SET status = 'RELEASED' WHERE milestone_id =
            (SELECT milestone_id FROM miniupwork.escrow_funding WHERE funding_id = NEW.escrow_funding_id);
    ELSIF NEW.transaction_type = 'HOURLY_CHARGE' THEN
        UPDATE miniupwork.weekly_invoice SET status = 'PAID' WHERE invoice_id = NEW.invoice_id;
        INSERT INTO miniupwork.payment_transaction
            (contract_id, payer_id, payee_id, invoice_id, amount, currency_code, transaction_type, status)
        VALUES
            (NEW.contract_id, NEW.payer_id, NEW.payee_id, NEW.invoice_id, NEW.amount, NEW.currency_code,
             'HOURLY_PAYOUT', 'SUCCEEDED');
    END IF;
    RETURN NULL;
END;
$$;
