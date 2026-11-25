-- [SEG] Truy vấn dữ liệu từng bảng (nhóm danh mục)
SELECT customer_id, customer_code, customer_name, customer_type, tax_code, phone FROM customers ORDER BY customer_id;
SELECT account_id, customer_id, bank_name, bank_bin, account_no, account_name, is_default FROM bank_accounts ORDER BY account_id;
SELECT employee_id, employee_code, full_name, role, hire_date FROM employees ORDER BY employee_id;
SELECT machine_id, machine_code, machine_name, machine_type, speed_ppm, status FROM machines ORDER BY machine_id;
SELECT product_id, product_code, product_name, category, unit_price FROM products ORDER BY product_id;
SELECT t.template_id, c.customer_name, p.product_name, t.template_name, t.version
  FROM templates t
  JOIN customers c ON c.customer_id = t.customer_id
  JOIN products  p ON p.product_id  = t.product_id
 ORDER BY t.template_id;

-- [SEG] Truy vấn dữ liệu từng bảng (nhóm nghiệp vụ)
SELECT o.order_code, c.customer_name, o.order_date, o.due_date, o.status, o.total_amount
  FROM orders o JOIN customers c ON c.customer_id = o.customer_id ORDER BY o.order_id;

SELECT j.job_code, o.order_code, m.machine_code, e.full_name AS operator_name,
       j.quantity, j.printed_count, j.status, pkg_print_ops.job_progress(j.job_id) AS progress_pct
  FROM print_jobs j
  JOIN orders o ON o.order_id = j.order_id
  LEFT JOIN machines  m ON m.machine_id  = j.machine_id
  LEFT JOIN employees e ON e.employee_id = j.operator_id
 ORDER BY j.job_id;

SELECT r.record_id, j.job_code, r.seq_no, r.recipient_name, r.amount, r.print_status
  FROM print_records r JOIN print_jobs j ON j.job_id = r.job_id ORDER BY r.job_id, r.seq_no;

SELECT q.qr_ref, r.recipient_name, q.amount, q.status, q.crc, SUBSTR(q.qr_payload, 1, 60) || '...' AS payload_preview
  FROM vietqr_codes q JOIN print_records r ON r.record_id = q.record_id ORDER BY q.qr_id;

SELECT p.bank_txn_ref, q.qr_ref, p.paid_amount, p.paid_at, p.match_status, p.payer_name
  FROM payments p LEFT JOIN vietqr_codes q ON q.qr_id = p.qr_id ORDER BY p.payment_id;

SELECT l.log_id, j.job_code, l.old_status, l.new_status, l.changed_at, l.message
  FROM job_logs l JOIN print_jobs j ON j.job_id = l.job_id ORDER BY l.log_id;

-- [SEG] Truy vấn tổng hợp: tỷ lệ thu tiền theo đơn hàng
SELECT o.order_code, c.customer_name,
       COUNT(q.qr_id)                                             AS qr_count,
       SUM(CASE WHEN q.status = 'PAID' THEN 1 ELSE 0 END)         AS qr_paid,
       NVL(SUM(q.amount), 0)                                      AS amount_to_collect,
       pkg_print_ops.collection_rate(o.order_id)                  AS collection_pct
  FROM orders o
  JOIN customers c ON c.customer_id = o.customer_id
  JOIN print_jobs j ON j.order_id = o.order_id
  JOIN print_records r ON r.job_id = j.job_id
  LEFT JOIN vietqr_codes q ON q.record_id = r.record_id
 GROUP BY o.order_id, o.order_code, c.customer_name
 ORDER BY o.order_id;
