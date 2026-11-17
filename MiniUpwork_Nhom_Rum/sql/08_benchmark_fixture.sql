-- Dữ liệu tải thử cho NFR-02. Chạy trong CSDL kiểm thử riêng đã nạp bộ Rum nguyên gốc.
BEGIN;
DO $$ BEGIN
    IF (SELECT count(*) FROM miniupwork.job) <> 50 OR (SELECT count(*) FROM miniupwork.proposal) <> 112 THEN
        RAISE EXCEPTION 'Use a separate, fresh Rum fixture database for the benchmark';
    END IF;
END; $$;

INSERT INTO miniupwork.job (job_id,client_id,category_id,title,description,job_type)
SELECT 100000+n,36+n%15,1+n%10,'Dự án '||n,'Đo truy vấn thị trường trên dữ liệu giả lập',
       CASE WHEN n%2=0 THEN 'FIXED_PRICE' ELSE 'HOURLY' END FROM generate_series(1,9950) n;
INSERT INTO miniupwork.fixed_price_job(job_id,budget_amount)
SELECT job_id,100+job_id%950 FROM miniupwork.job WHERE job_id>100000 AND job_type='FIXED_PRICE';
INSERT INTO miniupwork.hourly_job(job_id,rate_min,rate_max)
SELECT job_id,10+job_id%30,30+job_id%30 FROM miniupwork.job WHERE job_id>100000 AND job_type='HOURLY';
INSERT INTO miniupwork.job_skill(job_id,skill_id,required_level)
SELECT job_id,(category_id-1)*3+1,3 FROM miniupwork.job WHERE job_id>100000;
UPDATE miniupwork.job SET status='OPEN' WHERE job_id>100000;
INSERT INTO miniupwork.proposal (job_id,freelancer_id,cover_letter,offered_amount)
SELECT j.job_id,f,'Đề xuất thử truy vấn',100
FROM miniupwork.job j CROSS JOIN generate_series(1,6) AS f WHERE j.job_id>100000
LIMIT (SELECT 50000-count(*) FROM miniupwork.proposal);
SELECT setval(pg_get_serial_sequence('miniupwork.job','job_id'), max(job_id)) FROM miniupwork.job;
SET CONSTRAINTS ALL IMMEDIATE;
COMMIT;

ANALYZE miniupwork.job;
ANALYZE miniupwork.proposal;
ANALYZE miniupwork.job_skill;
