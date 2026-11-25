-- [SEG] Đặc tả package PKG_VIETQR
CREATE OR REPLACE PACKAGE pkg_vietqr AS
  e_invalid_input EXCEPTION;
  PRAGMA EXCEPTION_INIT (e_invalid_input, -20001);
  e_no_account    EXCEPTION;
  PRAGMA EXCEPTION_INIT (e_no_account, -20002);
  e_qr_exists     EXCEPTION;
  PRAGMA EXCEPTION_INIT (e_qr_exists, -20003);
  e_dup_payment   EXCEPTION;
  PRAGMA EXCEPTION_INIT (e_dup_payment, -20004);

  FUNCTION normalize_text (p_text IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION tlv            (p_id IN VARCHAR2, p_value IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION crc16_ccitt    (p_text IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC;
  FUNCTION build_payload  (p_bank_bin   IN VARCHAR2,
                           p_account_no IN VARCHAR2,
                           p_amount     IN NUMBER,
                           p_add_info   IN VARCHAR2) RETURN VARCHAR2;

  PROCEDURE generate_qr_for_record (p_record_id IN NUMBER);
  PROCEDURE generate_qr_for_job    (p_job_id IN NUMBER, p_generated OUT NUMBER);
  PROCEDURE reconcile_payment      (p_bank_txn_ref     IN  VARCHAR2,
                                    p_transfer_content IN  VARCHAR2,
                                    p_paid_amount      IN  NUMBER,
                                    p_paid_at          IN  TIMESTAMP,
                                    p_payer_name       IN  VARCHAR2,
                                    p_raw_json         IN  CLOB,
                                    p_match_status     OUT VARCHAR2);
END pkg_vietqr;
/

-- [SEG] Thân package PKG_VIETQR – hàm normalize_text bỏ dấu tiếng Việt
CREATE OR REPLACE PACKAGE BODY pkg_vietqr AS

  FUNCTION normalize_text (p_text IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    c_vn_lower    CONSTANT VARCHAR2(400 CHAR) :=
      'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    c_ascii_lower CONSTANT VARCHAR2(400 CHAR) :=
      RPAD('a', 17, 'a') || RPAD('e', 11, 'e') || RPAD('i', 5, 'i') ||
      RPAD('o', 17, 'o') || RPAD('u', 11, 'u') || RPAD('y', 5, 'y') || 'd';
  BEGIN
    IF p_text IS NULL THEN
      RETURN NULL;
    END IF;
    RETURN TRANSLATE(p_text,
                     c_vn_lower    || UPPER(c_vn_lower),
                     c_ascii_lower || UPPER(c_ascii_lower));
  END normalize_text;

  -- [SEG] Hàm tlv: mã hóa một trường Tag-Length-Value theo EMVCo
  FUNCTION tlv (p_id IN VARCHAR2, p_value IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
  BEGIN
    RETURN p_id || LPAD(TO_CHAR(LENGTH(p_value)), 2, '0') || p_value;
  END tlv;

  -- [SEG] Hàm crc16_ccitt: CRC-16/CCITT-FALSE (đa thức 0x1021, khởi tạo 0xFFFF)
  FUNCTION crc16_ccitt (p_text IN VARCHAR2) RETURN VARCHAR2 DETERMINISTIC IS
    v_crc PLS_INTEGER := 65535;                       -- 0xFFFF
    FUNCTION xor16 (a IN PLS_INTEGER, b IN PLS_INTEGER) RETURN PLS_INTEGER IS
    BEGIN
      RETURN a + b - 2 * BITAND(a, b);                -- XOR = a + b - 2*(a AND b)
    END xor16;
  BEGIN
    FOR i IN 1 .. LENGTH(p_text) LOOP
      v_crc := xor16(v_crc, ASCII(SUBSTR(p_text, i, 1)) * 256);
      FOR j IN 1 .. 8 LOOP
        IF BITAND(v_crc, 32768) <> 0 THEN             -- bit cao nhất (0x8000) bằng 1
          v_crc := BITAND(xor16(v_crc * 2, 4129), 65535);   -- 4129 = 0x1021
        ELSE
          v_crc := BITAND(v_crc * 2, 65535);
        END IF;
      END LOOP;
    END LOOP;
    RETURN LPAD(TO_CHAR(v_crc, 'FMXXXX'), 4, '0');
  END crc16_ccitt;

  -- [SEG] Hàm build_payload: dựng chuỗi VietQR động (NAPAS 247 – chuyển nhanh đến tài khoản)
  FUNCTION build_payload (p_bank_bin   IN VARCHAR2,
                          p_account_no IN VARCHAR2,
                          p_amount     IN NUMBER,
                          p_add_info   IN VARCHAR2) RETURN VARCHAR2 IS
    v_merchant VARCHAR2(200);
    v_data     VARCHAR2(600);
  BEGIN
    IF p_bank_bin IS NULL OR NOT REGEXP_LIKE(p_bank_bin, '^[0-9]{6}$') THEN
      RAISE_APPLICATION_ERROR(-20001, 'Ma BIN ngan hang khong hop le: ' || NVL(p_bank_bin, 'NULL'));
    END IF;
    IF p_account_no IS NULL OR NOT REGEXP_LIKE(p_account_no, '^[0-9A-Za-z]{1,19}$') THEN
      RAISE_APPLICATION_ERROR(-20001, 'So tai khoan nhan tien khong hop le');
    END IF;
    IF p_amount IS NOT NULL AND (p_amount < 0 OR p_amount <> TRUNC(p_amount)) THEN
      RAISE_APPLICATION_ERROR(-20001, 'So tien phai la so nguyen khong am (VND)');
    END IF;
    IF p_add_info IS NOT NULL AND LENGTH(p_add_info) > 25 THEN
      RAISE_APPLICATION_ERROR(-20001, 'Noi dung chuyen khoan toi da 25 ky tu');
    END IF;

    v_merchant := tlv('00', 'A000000727')                                   -- GUID NAPAS
               || tlv('01', tlv('00', p_bank_bin) || tlv('01', p_account_no)) -- BIN + số tài khoản
               || tlv('02', 'QRIBFTTA');                                    -- chuyển nhanh đến tài khoản

    v_data := tlv('00', '01')                                               -- phiên bản payload
           || tlv('01', CASE WHEN p_amount > 0 THEN '12' ELSE '11' END)     -- 12 = động, 11 = tĩnh
           || tlv('38', v_merchant)
           || tlv('53', '704')                                              -- tiền tệ VND
           || CASE WHEN p_amount > 0 THEN tlv('54', TO_CHAR(p_amount, 'FM999999999999990')) END
           || tlv('58', 'VN')
           || CASE WHEN p_add_info IS NOT NULL THEN tlv('62', tlv('08', p_add_info)) END
           || '6304';                                                       -- tiền tố của CRC
    RETURN v_data || crc16_ccitt(v_data);
  END build_payload;

  -- [SEG] Thủ tục generate_qr_for_record: sinh VietQR cho một bản ghi in
  PROCEDURE generate_qr_for_record (p_record_id IN NUMBER) IS
    v_amount  print_records.amount%TYPE;
    v_job_id  print_records.job_id%TYPE;
    v_acc     bank_accounts%ROWTYPE;
    v_ref     vietqr_codes.qr_ref%TYPE;
    v_payload vietqr_codes.qr_payload%TYPE;
  BEGIN
    SELECT r.amount, r.job_id INTO v_amount, v_job_id
      FROM print_records r WHERE r.record_id = p_record_id;

    SELECT a.* INTO v_acc
      FROM bank_accounts a
      JOIN orders     o ON o.customer_id = a.customer_id
      JOIN print_jobs j ON j.order_id    = o.order_id
     WHERE j.job_id = v_job_id AND a.is_default = 1 AND a.status = 'ACTIVE';

    v_ref     := 'PQ' || TO_CHAR(seq_qr_ref.NEXTVAL, 'FM0000000000');
    v_payload := build_payload(v_acc.bank_bin, v_acc.account_no, v_amount, v_ref);

    INSERT INTO vietqr_codes (record_id, account_id, qr_ref, amount, add_info,
                              qr_payload, crc, status, expired_at)
    VALUES (p_record_id, v_acc.account_id, v_ref, v_amount, v_ref,
            v_payload, SUBSTR(v_payload, -4), 'ACTIVE', SYSTIMESTAMP + INTERVAL '30' DAY);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20002,
        'Khong tim thay ban ghi hoac tai khoan nhan tien mac dinh (record_id=' || p_record_id || ')');
    WHEN DUP_VAL_ON_INDEX THEN
      RAISE_APPLICATION_ERROR(-20003, 'Ban ghi ' || p_record_id || ' da co ma VietQR');
  END generate_qr_for_record;

  -- [SEG] Thủ tục generate_qr_for_job: sinh VietQR hàng loạt cho cả lệnh in
 PROCEDURE generate_qr_for_job (p_job_id IN NUMBER, p_generated OUT NUMBER) IS
    v_msg VARCHAR2(300);
  BEGIN
    p_generated := 0;
    FOR r IN (SELECT pr.record_id
                FROM print_records pr
               WHERE pr.job_id = p_job_id
                 AND NOT EXISTS (SELECT 1 FROM vietqr_codes q WHERE q.record_id = pr.record_id)
               ORDER BY pr.seq_no) LOOP
      BEGIN
        generate_qr_for_record(r.record_id);
        p_generated := p_generated + 1;
      EXCEPTION
        WHEN e_no_account THEN
          RAISE;                                   -- thiếu tài khoản: dừng cả lệnh in
        WHEN OTHERS THEN
          v_msg := SUBSTR('Loi sinh QR record ' || r.record_id || ': ' || SQLERRM, 1, 300);
          INSERT INTO job_logs (job_id, message) VALUES (p_job_id, v_msg);
      END;
    END LOOP;
  END generate_qr_for_job;

  -- [SEG] Thủ tục reconcile_payment: đối soát giao dịch ngân hàng với mã VietQR
  PROCEDURE reconcile_payment (p_bank_txn_ref     IN  VARCHAR2,
                               p_transfer_content IN  VARCHAR2,
                               p_paid_amount      IN  NUMBER,
                               p_paid_at          IN  TIMESTAMP,
                               p_payer_name       IN  VARCHAR2,
                               p_raw_json         IN  CLOB,
                               p_match_status     OUT VARCHAR2) IS
    v_ref  vietqr_codes.qr_ref%TYPE;
    v_qr   vietqr_codes%ROWTYPE;
    v_dup  NUMBER;

    PROCEDURE save_payment (p_qr_id IN NUMBER) IS
    BEGIN
      INSERT INTO payments (qr_id, bank_txn_ref, paid_amount, paid_at, payer_name,
                            transfer_content, match_status, raw_payload)
      VALUES (p_qr_id, p_bank_txn_ref, p_paid_amount, p_paid_at, p_payer_name,
              SUBSTR(p_transfer_content, 1, 250), p_match_status, p_raw_json);
    END save_payment;
  BEGIN
    SELECT COUNT(*) INTO v_dup FROM payments WHERE bank_txn_ref = p_bank_txn_ref;
    IF v_dup > 0 THEN                                -- webhook gửi lặp: bảo đảm idempotent
      RAISE_APPLICATION_ERROR(-20004, 'Giao dich ' || p_bank_txn_ref || ' da duoc ghi nhan truoc do');
    END IF;

    v_ref := REGEXP_SUBSTR(UPPER(p_transfer_content), 'PQ[0-9]{10}');
    IF v_ref IS NULL THEN
      p_match_status := 'UNMATCHED';
      save_payment(NULL);
      RETURN;
    END IF;

    SELECT * INTO v_qr FROM vietqr_codes WHERE qr_ref = v_ref FOR UPDATE;

    p_match_status := CASE
      WHEN v_qr.status = 'PAID'                                THEN 'DUPLICATE'
      WHEN v_qr.status <> 'ACTIVE'                             THEN 'UNMATCHED'
      WHEN v_qr.amount > 0 AND v_qr.amount <> p_paid_amount    THEN 'AMOUNT_DIFF'
      ELSE 'MATCHED'
    END;
    save_payment(v_qr.qr_id);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN                          -- có mã PQ... nhưng không tồn tại
      p_match_status := 'UNMATCHED';
      save_payment(NULL);
    WHEN DUP_VAL_ON_INDEX THEN                       -- hai webhook trùng nhau đến cùng lúc
      RAISE_APPLICATION_ERROR(-20004, 'Giao dich ' || p_bank_txn_ref || ' da duoc ghi nhan truoc do');
  END reconcile_payment;

END pkg_vietqr;
/
