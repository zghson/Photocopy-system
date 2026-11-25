-- [SEG] JSON_VALUE và dot-notation: lấy trường đơn lẻ từ dữ liệu cá nhân hóa
SELECT r.seq_no,
       JSON_VALUE(r.variable_data, '$.full_name')                       AS full_name,
       JSON_VALUE(r.variable_data, '$.class')                           AS class_name,
       JSON_VALUE(r.variable_data, '$.total' RETURNING NUMBER)          AS total,
       r.variable_data.period.string()                                  AS period
  FROM print_records r
  JOIN print_jobs j ON j.job_id = r.job_id
  JOIN orders     o ON o.order_id = j.order_id
 WHERE o.customer_id = 1
 ORDER BY r.seq_no;

-- [SEG] JSON_EXISTS: lọc theo sự tồn tại và điều kiện trong mảng
-- học viên được giảm giá
SELECT r.recipient_name, JSON_VALUE(r.variable_data, '$.discount.percent') AS discount_pct
  FROM print_records r
 WHERE JSON_EXISTS(r.variable_data, '$.discount');

-- bản ghi có ít nhất một khoản thu từ 1.000.000 đồng trở lên
SELECT r.recipient_name, r.amount
  FROM print_records r
 WHERE JSON_EXISTS(r.variable_data, '$.items[*]?(@.amount >= 1000000)');

-- [SEG] JSON_TABLE: trải phẳng mảng items thành các dòng quan hệ và tổng hợp
SELECT r.recipient_name, it.item_name, it.item_amount
  FROM print_records r,
       JSON_TABLE(r.variable_data, '$.items[*]' COLUMNS (
         item_name   VARCHAR2(100) PATH '$.name',
         item_amount NUMBER        PATH '$.amount')) it
 ORDER BY r.record_id, it.item_name;

SELECT it.item_name, COUNT(*) AS times_billed, SUM(it.item_amount) AS total_amount
  FROM print_records r,
       JSON_TABLE(r.variable_data, '$.items[*]' COLUMNS (
         item_name   VARCHAR2(100) PATH '$.name',
         item_amount NUMBER        PATH '$.amount')) it
 GROUP BY it.item_name
 ORDER BY total_amount DESC;

-- [SEG] Truy vấn JSON trong bảng danh mục: brand_profile, spec, layout
SELECT c.customer_name,
       JSON_VALUE(c.brand_profile, '$.industry')        AS industry,
       JSON_VALUE(c.brand_profile, '$.brand_colors[0]') AS primary_color,
       ct.contact_name, ct.contact_role
  FROM customers c,
       JSON_TABLE(c.brand_profile, '$.contacts[*]' COLUMNS (
         contact_name VARCHAR2(100) PATH '$.name',
         contact_role VARCHAR2(50)  PATH '$.role')) ct;

-- máy in hỗ trợ in dữ liệu biến đổi và độ phân giải từ 1200 dpi
SELECT machine_code, machine_name, JSON_VALUE(spec, '$.resolution_dpi' RETURNING NUMBER) AS dpi
  FROM machines
 WHERE JSON_EXISTS(spec, '$?(@.variable_data == true && @.resolution_dpi >= 1200)');

-- vị trí và kích thước mã QR trên từng mẫu in
SELECT t.template_name,
       JSON_VALUE(t.layout, '$.qr.size_mm' RETURNING NUMBER) AS qr_size_mm,
       JSON_VALUE(t.layout, '$.qr.error_correction')         AS qr_ecc,
       JSON_VALUE(t.layout, '$.page.size')                   AS page_size
  FROM templates t ORDER BY t.template_id;

-- [SEG] JSON_TRANSFORM: cập nhật cục bộ tài liệu JSON mà không ghi lại toàn bộ
UPDATE print_records
   SET variable_data = JSON_TRANSFORM(variable_data, SET '$.reminder_count' = 1)
 WHERE print_status = 'PRINTED'
   AND JSON_VALUE(variable_data, '$.student_id') = 'HV0006';

SELECT JSON_SERIALIZE(variable_data PRETTY) AS doc
  FROM print_records WHERE JSON_VALUE(variable_data, '$.student_id') = 'HV0006';

-- [SEG] JSON_OBJECT, JSON_ARRAYAGG: sinh tài liệu JSON cho tầng API
SELECT JSON_SERIALIZE(
         JSON_OBJECT(
           'orderCode' VALUE o.order_code,
           'customer'  VALUE c.customer_name,
           'status'    VALUE o.status,
           'jobs'      VALUE (SELECT JSON_ARRAYAGG(
                                       JSON_OBJECT('jobCode'  VALUE j.job_code,
                                                   'status'   VALUE j.status,
                                                   'progress' VALUE pkg_print_ops.job_progress(j.job_id)))
                                FROM print_jobs j WHERE j.order_id = o.order_id) FORMAT JSON)
         PRETTY) AS order_json
  FROM orders o JOIN customers c ON c.customer_id = o.customer_id
 WHERE o.order_code LIKE 'DH%-0001';

-- [SEG] (Tùy chọn) JSON Relational Duality View: một tài liệu JSON gộp đơn hàng và các lệnh in
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW order_dv AS
SELECT JSON {
         '_id'       : o.order_id,
         'orderCode' : o.order_code,
         'status'    : o.status,
         'jobs'      : [ SELECT JSON { 'jobId'    : j.job_id,
                                       'jobCode'  : j.job_code,
                                       'quantity' : j.quantity,
                                       'status'   : j.status }
                           FROM print_jobs j
                          WHERE j.order_id = o.order_id ]
       }
  FROM orders o;

SELECT JSON_SERIALIZE(d.data PRETTY) FROM order_dv d WHERE d.data.orderCode.string() LIKE 'DH%-0001';
