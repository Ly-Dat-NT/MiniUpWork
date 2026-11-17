-- Kiểm tra nhanh trên bộ dữ liệu Rum vừa nạp. Các thao tác thử đều rollback.
BEGIN;
DO $$
DECLARE t RECORD;
BEGIN
    IF (SELECT COUNT(*) FROM miniupwork.app_user) <> 50
       OR (SELECT COUNT(*) FROM miniupwork.client) <> 15
       OR (SELECT COUNT(*) FROM miniupwork.freelancer) <> 35
       OR (SELECT COUNT(*) FROM miniupwork.client c JOIN miniupwork.freelancer f USING (user_id)) <> 0
       OR (SELECT COUNT(*) FROM miniupwork.category) <> 10
       OR (SELECT COUNT(*) FROM miniupwork.job) <> 50
       OR (SELECT COUNT(*) FROM miniupwork.job WHERE status <> 'DRAFT') <> 50
       OR (SELECT COUNT(*) FROM miniupwork.job WHERE status = 'OPEN') <> 10
       OR (SELECT COUNT(DISTINCT client_id) FROM miniupwork.job WHERE status <> 'DRAFT') <> 15
       OR (SELECT COUNT(*) FROM miniupwork.contract) <> 12
       OR (SELECT COUNT(*) FROM miniupwork.review) <> 12 THEN
        RAISE EXCEPTION 'Seed counts differ from the Rum dataset';
    END IF;

    FOR t IN SELECT * FROM (VALUES
        ('Thời gian chồng lấn', $q$
            INSERT INTO miniupwork.time_entry (entry_id,contract_id,start_at,end_at,description)
            SELECT 9999, 2, start_at, end_at, 'Kiểm thử thời gian chồng lấn'
            FROM miniupwork.time_entry WHERE contract_id = 2 ORDER BY entry_id LIMIT 1$q$),
        ('Nguồn hóa đơn khác hợp đồng', $q$
            INSERT INTO miniupwork.payment_transaction (payment_id,contract_id,payer_id,payee_id,invoice_id,transaction_type,amount)
            VALUES (9999,1,36,1,2,'HOURLY_CHARGE',168)$q$),
        ('Đánh giá hợp đồng đang làm', $q$
            INSERT INTO miniupwork.review (review_id,contract_id,reviewer_id,reviewee_id,rating,comment)
            VALUES (9999,1,36,1,5,'Kiểm thử đánh giá quá sớm')$q$),
        ('Sửa giao dịch đã ghi', $q$
            UPDATE miniupwork.payment_transaction SET amount = 1 WHERE payment_id = 1$q$)
    ) AS cases(label, command)
    LOOP
        BEGIN
            EXECUTE t.command;
            RAISE EXCEPTION 'Expected rejection: %', t.label;
        EXCEPTION WHEN check_violation THEN
            RAISE NOTICE 'PASS · %', t.label;
        END;
    END LOOP;
END;
$$;

SELECT (SELECT COUNT(*) FROM miniupwork.app_user) AS accounts,
       (SELECT COUNT(*) FROM miniupwork.client) AS clients,
       (SELECT COUNT(*) FROM miniupwork.freelancer) AS freelancers,
       (SELECT COUNT(*) FROM miniupwork.job) AS job_records,
       (SELECT COUNT(*) FROM miniupwork.job WHERE status = 'OPEN') AS open_jobs,
       (SELECT COUNT(*) FROM miniupwork.contract) AS contracts;
ROLLBACK;
