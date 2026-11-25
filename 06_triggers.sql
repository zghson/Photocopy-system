-- [SEG] Trigger TRG_PJ_VALIDATE_STATUS: kiểm soát máy trạng thái của lệnh in
CREATE OR REPLACE TRIGGER trg_pj_validate_status
BEFORE UPDATE OF status ON print_jobs
FOR EACH ROW
WHEN (OLD.status <> NEW.status)
DECLARE
  v_ok BOOLEAN;
BEGIN
  v_ok := (:OLD.status = 'PENDING'  AND :NEW.status IN ('QUEUED', 'FAILED'))
       OR (:OLD.status = 'QUEUED'   AND :NEW.status IN ('PRINTING', 'PENDING'))
       OR (:OLD.status = 'PRINTING' AND :NEW.status IN ('PAUSED', 'COMPLETED', 'FAILED'))
       OR (:OLD.status = 'PAUSED'   AND :NEW.status IN ('PRINTING', 'FAILED'))
       OR (:OLD.status = 'FAILED'   AND :NEW.status = 'QUEUED');
  IF NOT v_ok THEN
    RAISE_APPLICATION_ERROR(-20010,
      'Chuyen trang thai khong hop le: ' || :OLD.status || ' -> ' || :NEW.status);
  END IF;

  IF :NEW.status = 'QUEUED' AND :NEW.machine_id IS NULL THEN
    RAISE_APPLICATION_ERROR(-20011, 'Phai gan may in truoc khi xep hang lenh in');
  END IF;

  IF :NEW.status = 'PRINTING' AND :NEW.started_at IS NULL THEN
    :NEW.started_at := SYSTIMESTAMP;
  END IF;

  IF :NEW.status = 'COMPLETED' THEN
    IF :NEW.printed_count + :NEW.failed_count < :NEW.quantity THEN
      RAISE_APPLICATION_ERROR(-20012, 'Con ' ||
        (:NEW.quantity - :NEW.printed_count - :NEW.failed_count) || ' to chua in xong');
    END IF;
    :NEW.finished_at := SYSTIMESTAMP;
  END IF;
END trg_pj_validate_status;
/

-- [SEG] Trigger TRG_PJ_AUDIT: ghi nhật ký mọi thay đổi trạng thái lệnh in
CREATE OR REPLACE TRIGGER trg_pj_audit
AFTER INSERT OR UPDATE OF status ON print_jobs
FOR EACH ROW
BEGIN
  IF INSERTING THEN
    INSERT INTO job_logs (job_id, old_status, new_status, message)
    VALUES (:NEW.job_id, NULL, :NEW.status, 'Tao lenh in');
  ELSIF :OLD.status <> :NEW.status THEN
    INSERT INTO job_logs (job_id, old_status, new_status, message)
    VALUES (:NEW.job_id, :OLD.status, :NEW.status, 'Doi trang thai lenh in');
  END IF;
END trg_pj_audit;
/

-- [SEG] Trigger TRG_PAY_APPLY: khi đối soát khớp, đánh dấu mã VietQR đã thanh toán
CREATE OR REPLACE TRIGGER trg_pay_apply
AFTER INSERT ON payments
FOR EACH ROW
WHEN (NEW.match_status = 'MATCHED')
BEGIN
  UPDATE vietqr_codes
     SET status = 'PAID', paid_at = :NEW.paid_at
   WHERE qr_id = :NEW.qr_id AND status = 'ACTIVE';
END trg_pay_apply;
/

-- [SEG] Compound trigger TRG_PR_COUNTER: đồng bộ bộ đếm tờ đã in / lỗi của lệnh in
CREATE OR REPLACE TRIGGER trg_pr_counter
FOR INSERT OR UPDATE OF print_status ON print_records
COMPOUND TRIGGER
  TYPE t_job_set IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
  g_jobs t_job_set;                                   -- tập các lệnh in bị ảnh hưởng

  AFTER EACH ROW IS
  BEGIN
    g_jobs(:NEW.job_id) := 1;                         -- chỉ ghi nhớ, không truy vấn bảng đang đổi
  END AFTER EACH ROW;

  AFTER STATEMENT IS
    v_id PLS_INTEGER;
  BEGIN
    v_id := g_jobs.FIRST;
    WHILE v_id IS NOT NULL LOOP
      UPDATE print_jobs j
         SET (printed_count, failed_count) =
             (SELECT COUNT(CASE WHEN r.print_status = 'PRINTED' THEN 1 END),
                     COUNT(CASE WHEN r.print_status = 'FAILED'  THEN 1 END)
                FROM print_records r WHERE r.job_id = v_id)
       WHERE j.job_id = v_id;
      v_id := g_jobs.NEXT(v_id);
    END LOOP;
    g_jobs.DELETE;
  END AFTER STATEMENT;
END trg_pr_counter;
/
