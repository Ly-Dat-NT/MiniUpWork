-- ĐẠT · Q1. Tìm tin đang mở có kỹ năng phù hợp và giá trong tầm.
SELECT j.job_id, j.title, c.category_name, s.skill_name, f.budget_amount, h.rate_min, h.rate_max
FROM miniupwork.job j
JOIN miniupwork.category c USING (category_id)
JOIN miniupwork.job_skill js USING (job_id)
JOIN miniupwork.skill s USING (skill_id)
LEFT JOIN miniupwork.fixed_price_job f USING (job_id)
LEFT JOIN miniupwork.hourly_job h USING (job_id)
WHERE j.status = 'OPEN' AND c.category_name = 'Phát triển web' AND s.skill_name = 'Python'
  AND (f.budget_amount BETWEEN 300 AND 900 OR (h.rate_min <= 35 AND h.rate_max >= 20))
ORDER BY j.posted_at DESC, j.job_id;

-- ĐẠT · Q2. Chọn freelancer đáp ứng tất cả kỹ năng và mức độ của job 1.
SELECT f.user_id, u.full_name, f.headline
FROM miniupwork.job j
JOIN miniupwork.freelancer f ON f.user_id <> j.client_id
JOIN miniupwork.app_user u ON u.user_id = f.user_id
WHERE j.job_id = 1 AND j.status = 'OPEN' AND u.status = 'ACTIVE' AND f.availability = 'AVAILABLE'
  AND NOT EXISTS (
      SELECT 1 FROM miniupwork.job_skill js WHERE js.job_id = j.job_id
        AND NOT EXISTS (
            SELECT 1 FROM miniupwork.freelancer_skill fs WHERE fs.freelancer_id = f.user_id
             AND fs.skill_id = js.skill_id AND fs.proficiency_level >= js.required_level))
ORDER BY f.user_id;

-- ĐẠT · Q3. Đếm đề xuất và xếp hạng mức quan tâm trong từng danh mục.
WITH stats AS (
    SELECT j.job_id, j.title, j.category_id, COUNT(p.proposal_id) AS proposal_count,
           COUNT(*) FILTER (WHERE p.status <> 'WITHDRAWN') AS current_count
    FROM miniupwork.job j LEFT JOIN miniupwork.proposal p USING (job_id) GROUP BY j.job_id
)
SELECT c.category_name, s.job_id, s.title, s.proposal_count, s.current_count,
       DENSE_RANK() OVER (PARTITION BY s.category_id ORDER BY s.current_count DESC) AS category_rank
FROM stats s JOIN miniupwork.category c USING (category_id)
ORDER BY c.category_id, category_rank, s.job_id;

-- ĐẠT · Q4. Tỷ lệ chấp nhận trong số đề xuất đã có quyết định.
SELECT c.category_name, COUNT(p.proposal_id) AS submissions,
       COUNT(*) FILTER (WHERE p.status = 'ACCEPTED') AS accepted,
       ROUND(100.0 * COUNT(*) FILTER (WHERE p.status = 'ACCEPTED') /
             NULLIF(COUNT(*) FILTER (WHERE p.status IN ('ACCEPTED', 'REJECTED')), 0), 2) AS acceptance_pct
FROM miniupwork.category c LEFT JOIN miniupwork.job j USING (category_id)
LEFT JOIN miniupwork.proposal p USING (job_id)
GROUP BY c.category_id ORDER BY acceptance_pct DESC NULLS LAST, c.category_name;

-- SÂM · Q5. Tin chưa có đề xuất, kèm công ty và số kỹ năng yêu cầu.
SELECT j.job_id, j.title, j.status, c.company_name, COUNT(js.skill_id) AS skill_count
FROM miniupwork.job j JOIN miniupwork.client c ON c.user_id = j.client_id
LEFT JOIN miniupwork.job_skill js USING (job_id)
WHERE NOT EXISTS (SELECT 1 FROM miniupwork.proposal p WHERE p.job_id = j.job_id)
GROUP BY j.job_id, c.user_id ORDER BY j.job_id;

-- SÂM · Q6. Số hợp đồng và tỷ trọng trạng thái trong từng loại.
SELECT c.contract_type, c.status, COUNT(*) AS contract_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY c.contract_type), 2) AS share_pct
FROM miniupwork.contract c JOIN miniupwork.proposal p USING (proposal_id)
WHERE p.status = 'ACCEPTED'
GROUP BY c.contract_type, c.status ORDER BY c.contract_type, c.status;

-- SÂM · Q7. Freelancer có điểm nhận được cao hơn mức chung của nhóm được đánh giá.
WITH ratings AS (
    SELECT r.* FROM miniupwork.rating_summary r JOIN miniupwork.freelancer f USING (user_id)
    WHERE r.review_count > 0
)
SELECT u.username, u.full_name, r.review_count, r.avg_rating,
       DENSE_RANK() OVER (ORDER BY r.avg_rating DESC, r.review_count DESC) AS rank
FROM ratings r JOIN miniupwork.app_user u USING (user_id)
WHERE r.avg_rating > (SELECT SUM(rating_sum)::NUMERIC / SUM(review_count) FROM ratings)
ORDER BY rank, u.username;

-- HUY · Q8. Mốc quá hạn còn phải xử lý theo công ty và số ngày.
SELECT c.contract_id, j.title AS job, m.title AS milestone, cl.company_name,
       m.amount, m.status, CURRENT_DATE - m.due_date AS days_overdue
FROM miniupwork.milestone m JOIN miniupwork.contract c USING (contract_id)
JOIN miniupwork.proposal p USING (proposal_id) JOIN miniupwork.job j USING (job_id)
JOIN miniupwork.client cl ON cl.user_id = j.client_id
WHERE c.status = 'ACTIVE' AND m.due_date < CURRENT_DATE AND m.status NOT IN ('RELEASED', 'CANCELLED', 'REFUNDED')
ORDER BY days_overdue DESC, m.milestone_id;

-- HUY · Q9. Giờ chưa lập hóa đơn, theo hợp đồng và tuần UTC.
SELECT t.contract_id, t.billing_week AS week_start,
       u.full_name, ROUND(SUM(EXTRACT(epoch FROM t.end_at - t.start_at)) / 3600, 2) AS hours,
       ROUND(h.hourly_rate * SUM(EXTRACT(epoch FROM t.end_at - t.start_at)) / 3600, 2) AS amount
FROM miniupwork.time_entry t JOIN miniupwork.hourly_contract h USING (contract_id)
JOIN miniupwork.contract c USING (contract_id) JOIN miniupwork.proposal p USING (proposal_id)
JOIN miniupwork.app_user u ON u.user_id = p.freelancer_id
WHERE t.invoice_id IS NULL AND t.eligibility_status = 'ELIGIBLE' AND c.status = 'ACTIVE'
GROUP BY t.contract_id, week_start, h.hourly_rate, u.user_id ORDER BY week_start, t.contract_id;

-- HUY · Q10. Đối soát escrow và hóa đơn với sổ giao dịch, gồm khoản bù.
WITH sources AS (
    SELECT m.contract_id, 'ESCROW' AS source_type, e.funding_id AS source_id,
           CASE WHEN e.status IN ('REFUNDED', 'CANCELLED') THEN 0 ELSE e.funded_amount END AS amount_due, e.status AS source_status
    FROM miniupwork.escrow_funding e JOIN miniupwork.milestone m USING (milestone_id)
    UNION ALL
    SELECT i.contract_id, 'INVOICE', i.invoice_id, d.amount, i.status
    FROM miniupwork.weekly_invoice i CROSS JOIN LATERAL miniupwork.invoice_total(i.invoice_id) d
), posted AS (
    SELECT contract_id, CASE WHEN escrow_funding_id IS NULL THEN 'INVOICE' ELSE 'ESCROW' END AS source_type,
           COALESCE(escrow_funding_id, invoice_id) AS source_id,
           SUM(CASE WHEN transaction_type = 'REVERSAL' THEN -amount ELSE amount END) AS net_paid
    FROM miniupwork.payment_transaction
    WHERE status = 'SUCCEEDED' AND transaction_type IN ('ESCROW_RELEASE', 'HOURLY_CHARGE', 'REVERSAL')
    GROUP BY 1, 2, 3
)
SELECT s.*, COALESCE(p.net_paid, 0) AS net_paid, s.amount_due - COALESCE(p.net_paid, 0) AS remaining
FROM sources s LEFT JOIN posted p USING (contract_id, source_type, source_id)
ORDER BY s.contract_id, s.source_type, s.source_id;

-- HUY · Q11. Thu nhập freelancer theo tháng, đã trừ giao dịch bù.
SELECT u.username, u.full_name, date_trunc('month', t.created_at AT TIME ZONE 'UTC')::date AS month,
       t.currency_code, SUM(CASE WHEN t.transaction_type = 'REVERSAL' THEN -t.amount ELSE t.amount END) AS net_income,
       COUNT(DISTINCT t.contract_id) AS contracts
FROM miniupwork.payment_transaction t JOIN miniupwork.contract c USING (contract_id)
JOIN miniupwork.proposal p USING (proposal_id) JOIN miniupwork.app_user u ON u.user_id = p.freelancer_id
WHERE t.status = 'SUCCEEDED' AND t.transaction_type IN ('ESCROW_RELEASE', 'HOURLY_CHARGE', 'REVERSAL')
GROUP BY u.user_id, month, t.currency_code ORDER BY month DESC, net_income DESC, u.username;
