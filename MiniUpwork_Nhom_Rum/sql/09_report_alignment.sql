-- Align the installed schema with the attached report and diagrams.
ALTER TABLE miniupwork.client ADD COLUMN billing_address VARCHAR(255);
ALTER TABLE miniupwork.freelancer ADD COLUMN experience_level VARCHAR(50)
    CHECK (experience_level IN ('ENTRY', 'INTERMEDIATE', 'EXPERT'));
ALTER TABLE miniupwork.review ALTER COLUMN comment DROP NOT NULL;

CREATE OR REPLACE VIEW miniupwork.rating_summary AS
SELECT reviewee_id AS user_id, COUNT(*) AS review_count, SUM(rating) AS rating_sum,
       ROUND(AVG(rating), 2) AS avg_rating, MAX(submitted_at) AS updated_at
FROM miniupwork.review
GROUP BY reviewee_id;

CREATE VIEW miniupwork.weekly_invoice_summary AS
SELECT i.invoice_id, i.contract_id, i.period_start, i.period_end, i.status,
       totals.hours AS total_hours, totals.amount AS total_amount
FROM miniupwork.weekly_invoice i
LEFT JOIN LATERAL miniupwork.invoice_total(i.invoice_id) totals ON TRUE;

ALTER TABLE miniupwork.escrow_funding
    DROP CONSTRAINT escrow_funding_status_check,
    DROP CONSTRAINT escrow_funded_timestamp,
    DROP CONSTRAINT escrow_settled_timestamp,
    ADD CONSTRAINT escrow_funding_status_check CHECK (status IN ('PENDING', 'FUNDED', 'RELEASED', 'REFUNDED', 'CANCELLED')),
    ADD CONSTRAINT escrow_funded_timestamp CHECK ((status IN ('PENDING', 'CANCELLED')) = (funded_at IS NULL)),
    ADD CONSTRAINT escrow_settled_timestamp CHECK ((status IN ('RELEASED', 'REFUNDED', 'CANCELLED')) = (settled_at IS NOT NULL)),
    ADD COLUMN released_at TIMESTAMPTZ GENERATED ALWAYS AS (
        CASE WHEN status = 'RELEASED' THEN settled_at END
    ) STORED;

-- All rows created by the previous schema represent payments already posted.
ALTER TABLE miniupwork.payment_transaction
    ADD COLUMN status TEXT NOT NULL DEFAULT 'SUCCEEDED' CHECK (status IN ('PENDING', 'SUCCEEDED', 'FAILED')),
    DROP CONSTRAINT payment_transaction_original_payment_id_key;
ALTER TABLE miniupwork.payment_transaction ALTER COLUMN status SET DEFAULT 'PENDING';

DROP INDEX miniupwork.one_release_per_funding, miniupwork.one_release_per_invoice;
CREATE UNIQUE INDEX one_release_per_funding ON miniupwork.payment_transaction(escrow_funding_id)
    WHERE transaction_type = 'ESCROW_RELEASE' AND status IN ('PENDING', 'SUCCEEDED');
CREATE UNIQUE INDEX one_release_per_invoice ON miniupwork.payment_transaction(invoice_id)
    WHERE transaction_type = 'HOURLY_CHARGE' AND status IN ('PENDING', 'SUCCEEDED');
CREATE UNIQUE INDEX one_reversal_per_payment ON miniupwork.payment_transaction(original_payment_id)
    WHERE original_payment_id IS NOT NULL AND status IN ('PENDING', 'SUCCEEDED');

CREATE OR REPLACE FUNCTION miniupwork.guard_proposal_lifecycle()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, miniupwork AS $$
DECLARE
    parent_status TEXT;
    owner_id BIGINT;
    requires_open_job BOOLEAN;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status <> 'SUBMITTED' THEN
            RAISE EXCEPTION 'A new proposal starts in SUBMITTED'
                USING ERRCODE = '23514', CONSTRAINT = 'proposal_initial_status';
        END IF;
    ELSE
        IF NOT (
            (OLD.status = 'SUBMITTED' AND NEW.status IN ('SUBMITTED', 'SHORTLISTED', 'ACCEPTED', 'REJECTED', 'WITHDRAWN'))
            OR (OLD.status = 'SHORTLISTED' AND NEW.status IN ('ACCEPTED', 'REJECTED', 'WITHDRAWN'))
            OR (OLD.status = 'WITHDRAWN' AND NEW.status = 'SUBMITTED')
        ) THEN
            RAISE EXCEPTION 'The requested proposal status transition is not allowed'
                USING ERRCODE = '23514', CONSTRAINT = 'proposal_invalid_transition';
        END IF;

        IF NEW.status <> 'SUBMITTED' AND (
            NEW.cover_letter IS DISTINCT FROM OLD.cover_letter
            OR NEW.offered_amount IS DISTINCT FROM OLD.offered_amount
            OR NEW.submitted_at IS DISTINCT FROM OLD.submitted_at
        ) THEN
            IF NEW.status = 'WITHDRAWN' THEN
                RAISE EXCEPTION 'Withdrawal changes only the proposal status'
                    USING ERRCODE = '23514', CONSTRAINT = 'proposal_withdraw_changes';
            END IF;
            RAISE EXCEPTION 'A decision changes only the proposal status'
                USING ERRCODE = '23514', CONSTRAINT = 'proposal_decision_changes';
        END IF;
    END IF;

    requires_open_job := NEW.status IN ('SUBMITTED', 'SHORTLISTED', 'ACCEPTED');

    -- Dùng cùng khóa dòng với thao tác đóng job để tránh đọc trạng thái cũ.
    SELECT status, client_id INTO parent_status, owner_id
    FROM miniupwork.job
    WHERE job_id = NEW.job_id
    FOR UPDATE;

    IF owner_id = NEW.freelancer_id THEN
        RAISE EXCEPTION 'A user cannot submit a proposal to their own job'
            USING ERRCODE = '23514', CONSTRAINT = 'proposal_self_bid';
    END IF;

    -- Khi thiếu job, để khóa ngoại báo lỗi 23503.
    IF requires_open_job AND parent_status IS NOT NULL AND parent_status <> 'OPEN' THEN
        RAISE EXCEPTION 'Only OPEN jobs allow submission, shortlisting or acceptance'
            USING ERRCODE = '23514', CONSTRAINT = 'proposal_requires_open_job';
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
        EXISTS (SELECT 1 FROM miniupwork.milestone WHERE contract_id = NEW.contract_id AND status <> 'RELEASED')
        OR EXISTS (SELECT 1 FROM miniupwork.weekly_invoice WHERE contract_id = NEW.contract_id AND status <> 'PAID')
        OR EXISTS (SELECT 1 FROM miniupwork.time_entry WHERE contract_id = NEW.contract_id AND invoice_id IS NULL
                   AND eligibility_status = 'ELIGIBLE')
    ) THEN
        RAISE EXCEPTION 'Settle all work before completion' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.guard_work_state()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE live_status TEXT; paid BOOLEAN;
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
            SELECT EXISTS (SELECT 1 FROM miniupwork.payment_transaction WHERE invoice_id = NEW.invoice_id AND transaction_type = 'HOURLY_CHARGE' AND status = 'SUCCEEDED') INTO paid;
            IF NEW.status <> OLD.status AND NOT (
                (OLD.status = 'DRAFT' AND NEW.status = 'ISSUED' AND EXISTS (SELECT 1 FROM miniupwork.invoice_total(NEW.invoice_id)))
                OR (OLD.status = 'ISSUED' AND NEW.status IN ('APPROVED', 'DISPUTED'))
                OR (OLD.status = 'DISPUTED' AND NEW.status = 'DRAFT')
                OR (OLD.status = 'APPROVED' AND NEW.status = 'PAID' AND paid)
            ) THEN RAISE EXCEPTION 'Invalid invoice transition' USING ERRCODE = '23514'; END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.guard_funding()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE target RECORD;
BEGIN
    SELECT m.amount, m.status AS milestone_status, c.status AS contract_status INTO target
    FROM miniupwork.milestone m JOIN miniupwork.contract c USING (contract_id)
    WHERE m.milestone_id = NEW.milestone_id FOR UPDATE OF c;
    IF NOT FOUND OR target.contract_status IS DISTINCT FROM 'ACTIVE' THEN
        RAISE EXCEPTION 'Funding requires an active contract' USING ERRCODE = '23514';
    END IF;
    IF TG_OP = 'INSERT' THEN
        IF target.milestone_status NOT IN ('PLANNED', 'REFUNDED')
           OR NEW.status <> 'PENDING' OR NEW.funded_amount <> target.amount THEN
            RAISE EXCEPTION 'Funding starts as pending and matches the milestone amount' USING ERRCODE = '23514';
        END IF;
        NEW.funded_at := NULL;
    ELSE
        IF (NEW.funding_id, NEW.milestone_id, NEW.funded_amount, NEW.currency_code)
           IS DISTINCT FROM (OLD.funding_id, OLD.milestone_id, OLD.funded_amount, OLD.currency_code) THEN
            RAISE EXCEPTION 'Funding identity, currency and amount are immutable' USING ERRCODE = '23514';
        END IF;
        IF NEW.status = OLD.status THEN
            IF NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'Funding history is immutable' USING ERRCODE = '23514'; END IF;
            RETURN NEW;
        END IF;
        IF OLD.status = 'PENDING' AND NEW.status = 'FUNDED' THEN
            NEW.funded_at := now();
            NEW.settled_at := NULL;
        ELSIF OLD.status = 'PENDING' AND NEW.status = 'CANCELLED' THEN
            NEW.funded_at := NULL;
            NEW.settled_at := now();
        ELSIF OLD.status = 'FUNDED' AND (
            (NEW.status = 'REFUNDED' AND target.milestone_status = 'FUNDED')
            OR (NEW.status = 'RELEASED' AND EXISTS (
                SELECT 1 FROM miniupwork.payment_transaction
                WHERE escrow_funding_id = NEW.funding_id AND transaction_type = 'ESCROW_RELEASE' AND status = 'SUCCEEDED'
            ))
        ) THEN
            NEW.funded_at := OLD.funded_at;
            NEW.settled_at := now();
        ELSE
            RAISE EXCEPTION 'Invalid escrow funding transition' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION miniupwork.guard_payment()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE parties RECORD; original RECORD; expected NUMERIC;
BEGIN
    SELECT c.status, j.client_id, p.freelancer_id INTO parties
    FROM miniupwork.contract c JOIN miniupwork.proposal p USING (proposal_id)
    JOIN miniupwork.job j USING (job_id) WHERE c.contract_id = NEW.contract_id FOR UPDATE OF c;
    IF NOT FOUND THEN RAISE EXCEPTION 'Unknown contract' USING ERRCODE = '23503'; END IF;
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
        IF NOT FOUND OR original.status <> 'SUCCEEDED' OR original.transaction_type = 'REVERSAL' OR original.contract_id <> NEW.contract_id
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

DROP TRIGGER payment_immutable ON miniupwork.payment_transaction;
CREATE TRIGGER payment_immutable BEFORE DELETE ON miniupwork.payment_transaction
FOR EACH ROW EXECUTE FUNCTION miniupwork.protect_history();

DROP TRIGGER payment_guard ON miniupwork.payment_transaction;
CREATE TRIGGER payment_guard BEFORE INSERT OR UPDATE ON miniupwork.payment_transaction
FOR EACH ROW EXECUTE FUNCTION miniupwork.guard_payment();

DROP TRIGGER payment_settled ON miniupwork.payment_transaction;
CREATE TRIGGER payment_settled AFTER UPDATE OF status ON miniupwork.payment_transaction
FOR EACH ROW WHEN (OLD.status = 'PENDING' AND NEW.status = 'SUCCEEDED')
EXECUTE FUNCTION miniupwork.mark_settled();
