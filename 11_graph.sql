-- [SEG] Tạo SQL Property Graph trên các bảng quan hệ hiện có (không sao chép dữ liệu)
CREATE OR REPLACE PROPERTY GRAPH printqr_graph
  VERTEX TABLES (
    customers  KEY (customer_id) LABEL customer    PROPERTIES (customer_id, customer_code, customer_name),
    orders     KEY (order_id)    LABEL sales_order PROPERTIES (order_id, order_code, status),
    print_jobs KEY (job_id)      LABEL print_job   PROPERTIES (job_id, job_code, quantity, status),
    machines   KEY (machine_id)  LABEL machine     PROPERTIES (machine_id, machine_code, machine_name),
    employees  KEY (employee_id) LABEL employee    PROPERTIES (employee_id, employee_code, full_name)
  )
  EDGE TABLES (
    orders AS places
      KEY (order_id)
      SOURCE      KEY (customer_id) REFERENCES customers (customer_id)
      DESTINATION KEY (order_id)    REFERENCES orders (order_id)
      LABEL places PROPERTIES (order_date),
    print_jobs AS has_job
      KEY (job_id)
      SOURCE      KEY (order_id) REFERENCES orders (order_id)
      DESTINATION KEY (job_id)   REFERENCES print_jobs (job_id)
      LABEL has_job PROPERTIES (quantity),
    print_jobs AS runs_on
      KEY (job_id)
      SOURCE      KEY (job_id)     REFERENCES print_jobs (job_id)
      DESTINATION KEY (machine_id) REFERENCES machines (machine_id)
      LABEL runs_on PROPERTIES (started_at),
    print_jobs AS operated_by
      KEY (job_id)
      SOURCE      KEY (job_id)      REFERENCES print_jobs (job_id)
      DESTINATION KEY (operator_id) REFERENCES employees (employee_id)
      LABEL operated_by NO PROPERTIES
  );

-- [SEG] Truy vấn 1: lần theo đường đi Khách hàng → Đơn hàng → Lệnh in → Máy in
SELECT *
  FROM GRAPH_TABLE (printqr_graph
    MATCH (c IS customer) -[IS places]-> (o IS sales_order)
          -[IS has_job]-> (j IS print_job) -[IS runs_on]-> (m IS machine)
    WHERE c.customer_code = 'KH001'
    COLUMNS (c.customer_name AS customer, o.order_code, j.job_code, m.machine_name));

-- [SEG] Truy vấn 2: đi ngược từ máy in để biết những khách hàng nào đã dùng máy đó
SELECT *
  FROM GRAPH_TABLE (printqr_graph
    MATCH (m IS machine) <-[IS runs_on]- (j IS print_job)
          <-[IS has_job]- (o IS sales_order) <-[IS places]- (c IS customer)
    WHERE m.machine_code = 'MAY-IJ01'
    COLUMNS (m.machine_code, c.customer_name, o.order_code, j.quantity));

-- [SEG] Truy vấn 3: tổng hợp số lệnh in theo cặp khách hàng – máy in
SELECT customer, machine, COUNT(*) AS job_count, SUM(quantity) AS total_quantity
  FROM GRAPH_TABLE (printqr_graph
    MATCH (c IS customer) -[IS places]-> (o IS sales_order)
          -[IS has_job]-> (j IS print_job) -[IS runs_on]-> (m IS machine)
    COLUMNS (c.customer_name AS customer, m.machine_name AS machine, j.quantity))
 GROUP BY customer, machine
 ORDER BY job_count DESC, customer;

-- [SEG] Truy vấn 4: tìm các khách hàng có chung một nhân viên vận hành (đường đi 6 cạnh)
SELECT *
  FROM GRAPH_TABLE (printqr_graph
    MATCH (c1 IS customer) -[IS places]-> (o1 IS sales_order) -[IS has_job]-> (j1 IS print_job)
          -[IS operated_by]-> (e IS employee)
          <-[IS operated_by]- (j2 IS print_job) <-[IS has_job]- (o2 IS sales_order)
          <-[IS places]- (c2 IS customer)
    WHERE c1.customer_id < c2.customer_id
    COLUMNS (c1.customer_name AS customer_1, c2.customer_name AS customer_2, e.full_name AS shared_operator));
