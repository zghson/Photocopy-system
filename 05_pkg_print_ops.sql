-- [SEG] Đặc tả package PKG_PRINT_OPS
CREATE OR REPLACE PACKAGE pkg_print_ops AS
  e_invalid_state   EXCEPTION;
  PRAGMA EXCEPTION_INIT (e_invalid_state, -20010);
  e_record_mismatch EXCEPTION;
  PRAGMA EXCEPTION_INIT (e_record_mismatch, -20013);
  e_no_machine      EXCEPTION;
  PRAGMA EXCEPTION_INIT (e_no_machine, -20014);
  e_bad_input       EXCEPTION;
  PRAGMA EXCEPTION_INIT (e_bad_input, -20015);

  FUNCTION job_progress     (p_job_id   IN NUMBER) RETURN NUMBER;
  FUNCTION estimate_minutes (p_job_id   IN NUMBER) RETURN NUMBER;
  FUNCTION collection_rate  (p_order_id IN NUMBER) RETURN NUMBER;

  PROCEDURE create_order_with_job (p_customer_id IN  NUMBER,
                                   p_template_id IN  NUMBER,
                                   p_quantity    IN  NUMBER,
                                   p_due_date    IN  DATE,
                                   p_job_config  IN  CLOB,
                                   p_order_id    OUT NUMBER,
                                   p_job_id      OUT NUMBER);
  PROCEDURE import_records (p_job_id IN NUMBER, p_json IN CLOB, p_imported OUT NUMBER);
  PROCEDURE assign_machine (p_job_id IN NUMBER, p_operator_id IN NUMBER, p_machine_id OUT NUMBER);
  PROCEDURE start_job      (p_job_id IN NUMBER);
  PROCEDURE print_batch    (p_job_id IN NUMBER, p_batch_size IN NUMBER, p_printed OUT NUMBER);
  PROCEDURE finish_job     (p_job_id IN NUMBER);
END pkg_print_ops;
/

-- [SEG] Thân package PKG_PRINT_OPS – các hàm tính toán
CREATE OR REPLACE PACKAGE BODY pkg_print_ops AS

  FUNCTION job_progress (p_job_id IN NUMBER) RETURN NUMBER IS
    v_qty  print_jobs.quantity%TYPE;
    v_done NUMBER;
  BEGIN
    SELECT quantity, printed_count + failed_count INTO v_qty, v_done
      FROM print_jobs WHERE job_id = p_job_id;
    RETURN ROUND(100 * v_done / v_qty, 2);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
  END job_progress;

  FUNCTION estimate_minutes (p_job_id IN NUMBER) RETURN NUMBER IS
    v_min NUMBER;
  BEGIN
    SELECT CEIL((j.quantity - j.printed_count - j.failed_count) / m.speed_ppm) INTO v_min
      FROM print_jobs j JOIN machines m ON m.machine_id = j.machine_id
     WHERE j.job_id = p_job_id;
    RETURN v_min;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;            -- lệnh in chưa được gán máy
  END estimate_minutes;

  FUNCTION collection_rate (p_order_id IN NUMBER) RETURN NUMBER IS
    v_paid  NUMBER;
    v_total NUMBER;
  BEGIN
    SELECT NVL(SUM(CASE WHEN q.status = 'PAID' THEN q.amount END), 0), NVL(SUM(q.amount), 0)
      INTO v_paid, v_total
      FROM print_jobs j
      JOIN print_records r ON r.job_id    = j.job_id
      JOIN vietqr_codes  q ON q.record_id = r.record_id
     WHERE j.order_id = p_order_id;
    RETURN CASE WHEN v_total = 0 THEN 0 ELSE ROUND(100 * v_paid / v_total, 2) END;
  END collection_rate;

  -- [SEG] Thủ tục create_order_with_job: tạo đơn hàng và lệnh in
  PROCEDURE create_order_with_job (p_customer_id IN  NUMBER,
                                   p_template_id IN  NUMBER,
                                   p_quantity    IN  NUMBER,
                                   p_due_date    IN  DATE,
                                   p_job_config  IN  CLOB,
                                   p_order_id    OUT NUMBER,
                                   p_job_id      OUT NUMBER) IS
    v_tpl_customer templates.customer_id%TYPE;
    v_price        products.unit_price%TYPE;
  BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
      RAISE_APPLICATION_ERROR(-20015, 'So luong in phai lon hon 0');
    END IF;

    SELECT t.customer_id, p.unit_price INTO v_tpl_customer, v_price
      FROM templates t JOIN products p ON p.product_id = t.product_id
     WHERE t.template_id = p_template_id AND p.is_active = 1;

    IF v_tpl_customer <> p_customer_id THEN
      RAISE_APPLICATION_ERROR(-20015, 'Mau in khong thuoc khach hang da chon');
    END IF;

    INSERT INTO orders (order_code, customer_id, due_date, status, total_amount)
    VALUES ('DH' || TO_CHAR(SYSDATE, 'YYYY') || '-' || LPAD(seq_order_code.NEXTVAL, 4, '0'),
            p_customer_id, p_due_date, 'CONFIRMED', p_quantity * v_price)
    RETURNING order_id INTO p_order_id;

    INSERT INTO print_jobs (job_code, order_id, template_id, quantity, job_config)
    VALUES ('JOB-' || LPAD(seq_job_code.NEXTVAL, 4, '0'),
            p_order_id, p_template_id, p_quantity, p_job_config)
    RETURNING job_id INTO p_job_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20015, 'Khong tim thay mau in hoac san pham da ngung kinh doanh');
  END create_order_with_job;

  -- [SEG] Thủ tục import_records: nhập hàng loạt dữ liệu cá nhân hóa từ mảng JSON
  PROCEDURE import_records (p_job_id IN NUMBER, p_json IN CLOB, p_imported OUT NUMBER) IS
    v_qty    print_jobs.quantity%TYPE;
    v_status print_jobs.status%TYPE;
    v_valid  NUMBER;
  BEGIN
    SAVEPOINT sp_import;
    SELECT quantity, status INTO v_qty, v_status
      FROM print_jobs WHERE job_id = p_job_id FOR UPDATE;

    IF v_status <> 'PENDING' THEN
      RAISE_APPLICATION_ERROR(-20010, 'Chi nhap duoc du lieu khi lenh in dang o trang thai PENDING');
    END IF;
    SELECT CASE WHEN p_json IS JSON THEN 1 ELSE 0 END INTO v_valid FROM dual;
    IF v_valid = 0 THEN
      RAISE_APPLICATION_ERROR(-20013, 'Du lieu nhap khong phai JSON hop le');
    END IF;

    INSERT INTO print_records (job_id, seq_no, recipient_name, amount, variable_data)
    SELECT p_job_id, jt.seq_no, jt.recipient_name, jt.amount, jt.data
      FROM JSON_TABLE(p_json, '$[*]' COLUMNS (
             seq_no         FOR ORDINALITY,
             recipient_name VARCHAR2(150) PATH '$.full_name',
             amount         NUMBER        PATH '$.total',
             data           VARCHAR2(4000) FORMAT JSON PATH '$')) jt;
    p_imported := SQL%ROWCOUNT;

    IF p_imported <> v_qty THEN
      RAISE_APPLICATION_ERROR(-20013,
        'So ban ghi (' || p_imported || ') khong khop so luong dat in (' || v_qty || ')');
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20010, 'Lenh in khong ton tai');
    WHEN OTHERS THEN
      ROLLBACK TO sp_import;                         -- hoàn tác phần đã chèn rồi ném lỗi lên trên
      RAISE;
  END import_records;

  -- [SEG] Thủ tục assign_machine: chọn máy rảnh nhanh nhất và xếp hàng lệnh in
  PROCEDURE assign_machine (p_job_id IN NUMBER, p_operator_id IN NUMBER, p_machine_id OUT NUMBER) IS
  BEGIN
    SELECT machine_id INTO p_machine_id
      FROM machines
     WHERE status = 'IDLE'
     ORDER BY speed_ppm DESC
     FETCH FIRST 1 ROW ONLY;

    UPDATE machines SET status = 'BUSY'
     WHERE machine_id = p_machine_id AND status = 'IDLE';      -- khóa lạc quan
    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20014, 'May in vua duoc lenh khac chiem, vui long thu lai');
    END IF;

    UPDATE print_jobs
       SET machine_id = p_machine_id, operator_id = p_operator_id, status = 'QUEUED'
     WHERE job_id = p_job_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20014, 'Khong con may in nao o trang thai IDLE');
  END assign_machine;

  -- [SEG] Các thủ tục start_job, print_batch, finish_job: điều khiển vòng đời lệnh in
  PROCEDURE start_job (p_job_id IN NUMBER) IS
    v_order print_jobs.order_id%TYPE;
  BEGIN
    UPDATE print_jobs SET status = 'PRINTING'
     WHERE job_id = p_job_id RETURNING order_id INTO v_order;
    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Khong tim thay lenh in');
    END IF;
    UPDATE orders SET status = 'IN_PRODUCTION' WHERE order_id = v_order AND status <> 'IN_PRODUCTION';
  END start_job;

  PROCEDURE print_batch (p_job_id IN NUMBER, p_batch_size IN NUMBER, p_printed OUT NUMBER) IS
    v_status print_jobs.status%TYPE;
  BEGIN
    SELECT status INTO v_status FROM print_jobs WHERE job_id = p_job_id;
    IF v_status <> 'PRINTING' THEN
      RAISE_APPLICATION_ERROR(-20010, 'Lenh in chua o trang thai PRINTING');
    END IF;
    UPDATE print_records
       SET print_status = 'PRINTED', printed_at = SYSTIMESTAMP
     WHERE record_id IN (SELECT record_id FROM print_records
                          WHERE job_id = p_job_id AND print_status = 'WAITING'
                          ORDER BY seq_no FETCH FIRST p_batch_size ROWS ONLY);
    p_printed := SQL%ROWCOUNT;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20010, 'Lenh in khong ton tai');
  END print_batch;

  PROCEDURE finish_job (p_job_id IN NUMBER) IS
    v_order   print_jobs.order_id%TYPE;
    v_machine print_jobs.machine_id%TYPE;
    v_open    NUMBER;
  BEGIN
    UPDATE print_jobs SET status = 'COMPLETED'
     WHERE job_id = p_job_id RETURNING order_id, machine_id INTO v_order, v_machine;
    IF SQL%ROWCOUNT = 0 THEN
      RAISE_APPLICATION_ERROR(-20010, 'Khong tim thay lenh in');
    END IF;
    UPDATE machines SET status = 'IDLE' WHERE machine_id = v_machine;
    SELECT COUNT(*) INTO v_open FROM print_jobs WHERE order_id = v_order AND status <> 'COMPLETED';
    IF v_open = 0 THEN
      UPDATE orders SET status = 'COMPLETED' WHERE order_id = v_order;
    END IF;
  END finish_job;

END pkg_print_ops;
/
