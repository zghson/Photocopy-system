-- [SEG] View xếp hạng hiệu suất máy in (RANK, RATIO_TO_REPORT)
CREATE OR REPLACE VIEW vw_machine_ranking AS
SELECT m.machine_code,
       m.machine_name,
       m.speed_ppm,
       NVL(SUM(j.printed_count), 0)                                   AS total_printed,
       RANK() OVER (ORDER BY NVL(SUM(j.printed_count), 0) DESC)       AS printed_rank,
       ROUND(100 * RATIO_TO_REPORT(NVL(SUM(j.printed_count), 0)) OVER (), 2) AS share_pct
  FROM machines m
  LEFT JOIN print_jobs j ON j.machine_id = m.machine_id
 GROUP BY m.machine_id, m.machine_code, m.machine_name, m.speed_ppm;

-- [SEG] View doanh số thu theo ngày với lũy kế và so sánh ngày trước (SUM OVER, LAG)
CREATE OR REPLACE VIEW vw_daily_collection AS
SELECT TRUNC(paid_at)                                          AS pay_date,
       COUNT(*)                                                AS txn_count,
       SUM(paid_amount)                                        AS daily_amount,
       SUM(SUM(paid_amount)) OVER (ORDER BY TRUNC(paid_at))    AS running_total,
       LAG(SUM(paid_amount)) OVER (ORDER BY TRUNC(paid_at))    AS prev_day_amount,
       SUM(paid_amount) - LAG(SUM(paid_amount)) OVER (ORDER BY TRUNC(paid_at)) AS diff_vs_prev
  FROM payments
 WHERE match_status = 'MATCHED'
 GROUP BY TRUNC(paid_at);

-- [SEG] View doanh thu và phân hạng khách hàng (DENSE_RANK, NTILE)
CREATE OR REPLACE VIEW vw_customer_revenue AS
SELECT c.customer_code,
       c.customer_name,
       COUNT(DISTINCT o.order_id)                                      AS order_count,
       NVL(SUM(o.total_amount), 0)                                     AS print_fee,
       DENSE_RANK() OVER (ORDER BY NVL(SUM(o.total_amount), 0) DESC)   AS revenue_rank,
       NTILE(2)     OVER (ORDER BY NVL(SUM(o.total_amount), 0) DESC)   AS tier
  FROM customers c
  LEFT JOIN orders o ON o.customer_id = c.customer_id
 GROUP BY c.customer_id, c.customer_code, c.customer_name;

-- [SEG] View thời gian từ lúc in đến lúc khách thanh toán (PARTITION BY, AVG OVER, RANK)
CREATE OR REPLACE VIEW vw_payment_delay AS
SELECT customer_code, recipient_name, qr_ref, hours_to_pay,
       ROUND(AVG(hours_to_pay) OVER (PARTITION BY customer_code), 1)  AS avg_hours_customer,
       RANK() OVER (PARTITION BY customer_code ORDER BY hours_to_pay) AS fastest_rank
  FROM (SELECT c.customer_code, r.recipient_name, q.qr_ref,
               ROUND((CAST(q.paid_at AS DATE) - CAST(r.printed_at AS DATE)) * 24, 1) AS hours_to_pay
          FROM vietqr_codes q
          JOIN print_records r ON r.record_id = q.record_id
          JOIN print_jobs    j ON j.job_id    = r.job_id
          JOIN orders        o ON o.order_id  = j.order_id
          JOIN customers     c ON c.customer_id = o.customer_id
         WHERE q.status = 'PAID');

-- [SEG] Truy vấn sử dụng các view window function
SELECT * FROM vw_machine_ranking ORDER BY printed_rank, machine_code;
SELECT * FROM vw_daily_collection ORDER BY pay_date;
SELECT * FROM vw_customer_revenue ORDER BY revenue_rank, customer_code;
SELECT * FROM vw_payment_delay ORDER BY customer_code, fastest_rank;
