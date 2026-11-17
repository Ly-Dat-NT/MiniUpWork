-- Forward-only upgrade of a seeded Mini-Upwork Rum database.
ALTER TABLE miniupwork.time_entry
    ADD COLUMN eligibility_status TEXT NOT NULL DEFAULT 'ELIGIBLE' CHECK (eligibility_status IN ('ELIGIBLE', 'INELIGIBLE')),
    ADD CONSTRAINT invoiced_entry_eligible CHECK (invoice_id IS NULL OR eligibility_status = 'ELIGIBLE');

ALTER TABLE miniupwork.escrow_funding DISABLE TRIGGER funding_guard;
ALTER TABLE miniupwork.escrow_funding
    ADD COLUMN currency_code CHAR(3) NOT NULL DEFAULT 'USD' CHECK (currency_code = 'USD'),
    ADD COLUMN settled_at TIMESTAMPTZ,
    ALTER COLUMN funded_at DROP NOT NULL,
    DROP CONSTRAINT escrow_funding_status_check;

UPDATE miniupwork.escrow_funding e SET settled_at = COALESCE(
    (SELECT min(p.created_at) FROM miniupwork.payment_transaction p
     WHERE p.escrow_funding_id = e.funding_id AND p.transaction_type = 'ESCROW_RELEASE'), e.funded_at)
WHERE e.status IN ('RELEASED', 'REFUNDED');

ALTER TABLE miniupwork.escrow_funding
    ADD CONSTRAINT escrow_funding_status_check CHECK (status IN ('PENDING', 'FUNDED', 'RELEASED', 'REFUNDED')),
    ADD CONSTRAINT escrow_funded_timestamp CHECK ((status = 'PENDING') = (funded_at IS NULL)),
    ADD CONSTRAINT escrow_settled_timestamp CHECK ((status IN ('RELEASED', 'REFUNDED')) = (settled_at IS NOT NULL));
DROP INDEX miniupwork.one_active_funding;
CREATE UNIQUE INDEX one_active_funding ON miniupwork.escrow_funding(milestone_id) WHERE status IN ('PENDING', 'FUNDED');
ALTER TABLE miniupwork.escrow_funding ENABLE TRIGGER funding_guard;

CREATE INDEX job_open_category_type_recent ON miniupwork.job(category_id, job_type, posted_at DESC, job_id DESC) WHERE status = 'OPEN';
CREATE INDEX job_open_recent ON miniupwork.job(posted_at DESC, job_id DESC) WHERE status = 'OPEN';

CREATE OR REPLACE FUNCTION miniupwork.invoice_total(target BIGINT)
RETURNS TABLE(hours NUMERIC, amount NUMERIC) LANGUAGE sql STABLE AS $$
    SELECT ROUND(SUM(EXTRACT(epoch FROM (e.end_at - e.start_at))) / 3600.0, 2),
           ROUND(SUM(EXTRACT(epoch FROM (e.end_at - e.start_at))) * h.hourly_rate / 3600.0, 2)
    FROM miniupwork.weekly_invoice AS i
    JOIN miniupwork.hourly_contract AS h USING (contract_id)
    JOIN miniupwork.time_entry AS e USING (invoice_id)
    WHERE i.invoice_id = target AND e.eligibility_status = 'ELIGIBLE'
    GROUP BY h.hourly_rate;
$$;

CREATE FUNCTION miniupwork.check_entry_start()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF (NEW.start_at AT TIME ZONE 'UTC')::date < (
        SELECT start_date FROM miniupwork.contract WHERE contract_id = NEW.contract_id
    ) THEN
        RAISE EXCEPTION 'Time entry precedes contract start' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER time_entry_start_guard BEFORE INSERT OR UPDATE ON miniupwork.time_entry
FOR EACH ROW EXECUTE FUNCTION miniupwork.check_entry_start();

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
                OR (OLD.status IN ('FUNDED','SUBMITTED','APPROVED') AND NEW.status = 'REFUNDED'
                    AND EXISTS (SELECT 1 FROM miniupwork.escrow_funding WHERE milestone_id = NEW.milestone_id AND status = 'REFUNDED')
                    AND NOT EXISTS (SELECT 1 FROM miniupwork.escrow_funding WHERE milestone_id = NEW.milestone_id AND status IN ('PENDING','FUNDED')))
                OR (OLD.status = 'APPROVED' AND NEW.status = 'RELEASED' AND EXISTS
                    (SELECT 1 FROM miniupwork.payment_transaction p JOIN miniupwork.escrow_funding e ON e.funding_id = p.escrow_funding_id
                     WHERE e.milestone_id = NEW.milestone_id AND p.transaction_type = 'ESCROW_RELEASE'))
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
            SELECT EXISTS (SELECT 1 FROM miniupwork.payment_transaction WHERE invoice_id = NEW.invoice_id AND transaction_type = 'HOURLY_CHARGE') INTO paid;
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
        ELSIF OLD.status = 'FUNDED' AND (NEW.status = 'REFUNDED' OR (NEW.status = 'RELEASED' AND EXISTS
            (SELECT 1 FROM miniupwork.payment_transaction WHERE escrow_funding_id = NEW.funding_id AND transaction_type = 'ESCROW_RELEASE'))) THEN
            NEW.funded_at := OLD.funded_at;
            NEW.settled_at := now();
        ELSE
            RAISE EXCEPTION 'Invalid escrow funding transition' USING ERRCODE = '23514';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

ALTER TABLE miniupwork.escrow_funding ALTER COLUMN status SET DEFAULT 'PENDING';
ALTER TABLE miniupwork.escrow_funding ALTER COLUMN funded_at DROP DEFAULT;

CREATE FUNCTION miniupwork.sync_funding_status()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status IN ('FUNDED', 'REFUNDED') AND NEW.status <> OLD.status THEN
        UPDATE miniupwork.milestone SET status = NEW.status WHERE milestone_id = NEW.milestone_id;
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER escrow_milestone_sync AFTER UPDATE OF status ON miniupwork.escrow_funding
FOR EACH ROW EXECUTE FUNCTION miniupwork.sync_funding_status();

-- Published jobs can close or cancel via the client workspace. Drafts can open or cancel.
-- Runtime privileges intentionally never include DELETE on jobs, users, or financial history.

CREATE FUNCTION miniupwork.check_termination_balances()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.status = 'TERMINATED' AND OLD.status <> NEW.status AND (
        EXISTS (SELECT 1 FROM miniupwork.escrow_funding e JOIN miniupwork.milestone m USING (milestone_id)
                WHERE m.contract_id=NEW.contract_id AND e.status IN ('PENDING','FUNDED'))
        OR EXISTS (SELECT 1 FROM miniupwork.weekly_invoice WHERE contract_id=NEW.contract_id AND status='APPROVED')
    ) THEN
        RAISE EXCEPTION 'Settle held escrow and approved invoices before termination'
            USING ERRCODE = '23514', CONSTRAINT = 'contract_has_held_balance';
    END IF;
    RETURN NEW;
END;
$$;
CREATE TRIGGER contract_balances_guard BEFORE UPDATE OF status ON miniupwork.contract
FOR EACH ROW EXECUTE FUNCTION miniupwork.check_termination_balances();
