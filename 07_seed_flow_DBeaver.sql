-- ===== Dữ liệu nghiệp vụ mẫu (bản DBeaver: dùng package tạm pkg_seed thay cho thủ tục lồng trong DECLARE) =====
-- Bản v3: không dùng dòng '/' (DBeaver tự tách theo END; của từng khối). Chạy bằng Alt+X; xem DBMS_OUTPUT ở Window > Database Output
CREATE OR REPLACE PACKAGE pkg_seed AS
  PROCEDURE new_job (p_cust IN NUMBER, p_tpl IN NUMBER, p_qty IN NUMBER, p_json IN CLOB, p_job OUT NUMBER);
  PROCEDURE run_print (p_job IN NUMBER, p_oper IN NUMBER, p_days_ago IN NUMBER, p_batch IN NUMBER);
  PROCEDURE pay (p_job IN NUMBER, p_seq IN NUMBER, p_txn IN VARCHAR2, p_hours IN NUMBER, p_adjust IN NUMBER DEFAULT 0);
END pkg_seed;
CREATE OR REPLACE PACKAGE BODY pkg_seed AS
  -- tạo đơn hàng + lệnh in, nhập dữ liệu JSON, sinh VietQR
  PROCEDURE new_job (p_cust IN NUMBER, p_tpl IN NUMBER, p_qty IN NUMBER, p_json IN CLOB, p_job OUT NUMBER) IS
    v_order NUMBER;
    v_n     NUMBER;
  BEGIN
    pkg_print_ops.create_order_with_job(p_cust, p_tpl, p_qty, TRUNC(SYSDATE) + 7, NULL, v_order, p_job);
    pkg_print_ops.import_records(p_job, p_json, v_n);
    pkg_vietqr.generate_qr_for_job(p_job, v_n);
  END new_job;
  -- gán máy, bắt đầu in, in một lô và lùi mốc thời gian in về quá khứ
  PROCEDURE run_print (p_job IN NUMBER, p_oper IN NUMBER, p_days_ago IN NUMBER, p_batch IN NUMBER) IS
    v_m NUMBER;
    v_n NUMBER;
  BEGIN
    pkg_print_ops.assign_machine(p_job, p_oper, v_m);
    pkg_print_ops.start_job(p_job);
    pkg_print_ops.print_batch(p_job, p_batch, v_n);
    UPDATE print_records
       SET printed_at = printed_at - NUMTODSINTERVAL(p_days_ago, 'DAY')
     WHERE job_id = p_job AND print_status = 'PRINTED';
  END run_print;
  -- mô phỏng webhook ngân hàng cho bản ghi thứ p_seq của lệnh in p_job
  PROCEDURE pay (p_job IN NUMBER, p_seq IN NUMBER, p_txn IN VARCHAR2, p_hours IN NUMBER, p_adjust IN NUMBER DEFAULT 0) IS
    v_ref     vietqr_codes.qr_ref%TYPE;
    v_amt     vietqr_codes.amount%TYPE;
    v_printed print_records.printed_at%TYPE;
    v_name    print_records.recipient_name%TYPE;
    v_st      VARCHAR2(12);
  BEGIN
    SELECT q.qr_ref, q.amount, r.printed_at, r.recipient_name
      INTO v_ref, v_amt, v_printed, v_name
      FROM print_records r JOIN vietqr_codes q ON q.record_id = r.record_id
     WHERE r.job_id = p_job AND r.seq_no = p_seq;
    pkg_vietqr.reconcile_payment(p_txn,
        v_ref || ' ' || pkg_vietqr.normalize_text(v_name),
        v_amt + p_adjust,
        v_printed + NUMTODSINTERVAL(p_hours, 'HOUR'),
        UPPER(pkg_vietqr.normalize_text(v_name)), NULL, v_st);
  END pay;
END pkg_seed;
DECLARE
  vA NUMBER; vB NUMBER; vC NUMBER; vD NUMBER;
  v_status VARCHAR2(12);
BEGIN
  -- Lệnh in A: phiếu thu học phí (KH001, 6 học viên)
  pkg_seed.new_job(1, 1, 6, q'~[
   {"student_id":"HV0001","full_name":"Nguyễn Minh Anh","class":"IELTS 6.5 - K12","period":"Tháng 11/2026","items":[{"name":"Học phí","amount":2800000},{"name":"Giáo trình","amount":350000}],"total":3150000},
   {"student_id":"HV0002","full_name":"Trần Gia Bảo","class":"IELTS 6.5 - K12","period":"Tháng 11/2026","items":[{"name":"Học phí","amount":2800000}],"total":2800000},
   {"student_id":"HV0003","full_name":"Lê Khánh Chi","class":"Giao tiếp - K08","period":"Tháng 11/2026","items":[{"name":"Học phí","amount":2200000},{"name":"Giáo trình","amount":250000}],"discount":{"type":"SIBLING","percent":10},"total":2205000},
   {"student_id":"HV0004","full_name":"Phạm Quốc Huy","class":"Giao tiếp - K08","period":"Tháng 11/2026","items":[{"name":"Học phí","amount":2200000}],"total":2200000},
   {"student_id":"HV0005","full_name":"Đỗ Thảo Nguyên","class":"Thiếu nhi - K03","period":"Tháng 11/2026","items":[{"name":"Học phí","amount":1800000},{"name":"Ngoại khóa","amount":200000}],"total":2000000},
   {"student_id":"HV0006","full_name":"Võ Thành Đạt","class":"IELTS 7.0 - K05","period":"Tháng 11/2026","items":[{"name":"Học phí","amount":3500000},{"name":"Giáo trình","amount":400000}],"total":3900000}
  ]~', vA);
  -- Lệnh in B: phiếu tạm ứng viện phí (KH002, 4 bệnh nhân)
  pkg_seed.new_job(2, 2, 4, q'~[
   {"patient_id":"BN2611-001","full_name":"Hoàng Văn Long","service":"Khám tổng quát","visit_date":"2026-11-12","items":[{"name":"Tạm ứng khám","amount":500000}],"total":500000},
   {"patient_id":"BN2611-002","full_name":"Nguyễn Thị Hạnh","service":"Siêu âm bụng","visit_date":"2026-11-13","items":[{"name":"Siêu âm","amount":350000},{"name":"Xét nghiệm máu","amount":420000}],"total":770000},
   {"patient_id":"BN2611-003","full_name":"Trần Đức Thịnh","service":"Nội soi dạ dày","visit_date":"2026-11-14","items":[{"name":"Nội soi","amount":1200000}],"total":1200000},
   {"patient_id":"BN2611-004","full_name":"Lý Mỹ Duyên","service":"Khám da liễu","visit_date":"2026-11-14","items":[{"name":"Tạm ứng khám","amount":400000}],"total":400000}
  ]~', vB);
  -- Lệnh in C: thư mời kèm phí tham dự (KH003, 5 khách mời)
  pkg_seed.new_job(3, 3, 5, q'~[
   {"guest_id":"GM001","full_name":"Bùi Anh Tuấn","title":"Giám đốc","company":"Công ty ABC","tier":"VIP","items":[{"name":"Phí tham dự VIP","amount":1000000}],"total":1000000},
   {"guest_id":"GM002","full_name":"Ngô Thị Thanh","title":"Trưởng phòng","company":"Công ty XYZ","tier":"STANDARD","items":[{"name":"Phí tham dự","amount":500000}],"total":500000},
   {"guest_id":"GM003","full_name":"Dương Quang Vinh","title":"Chuyên viên","company":"Công ty Minh Long","tier":"STANDARD","items":[{"name":"Phí tham dự","amount":500000}],"total":500000},
   {"guest_id":"GM004","full_name":"Huỳnh Mai Phương","title":"Phó giám đốc","company":"Tập đoàn Phát Đạt","tier":"VIP","items":[{"name":"Phí tham dự VIP","amount":1000000}],"total":1000000},
   {"guest_id":"GM005","full_name":"Cao Văn Lộc","title":"Kỹ sư","company":"Công ty An Phú","tier":"STANDARD","items":[{"name":"Phí tham dự","amount":500000}],"total":500000}
  ]~', vC);
  -- Lệnh in D: thông báo công nợ đại lý (KH004, 4 đại lý) – đang in dở
  pkg_seed.new_job(4, 4, 4, q'~[
   {"dealer_code":"DL001","full_name":"Đại lý Minh Phát","items":[{"name":"HD-1021","amount":8400000},{"name":"HD-1034","amount":5100000}],"total":13500000},
   {"dealer_code":"DL002","full_name":"Đại lý Bảy Hòa","items":[{"name":"HD-1025","amount":6200000}],"total":6200000},
   {"dealer_code":"DL003","full_name":"Đại lý Thanh Tâm","items":[{"name":"HD-1030","amount":9750000}],"total":9750000},
   {"dealer_code":"DL004","full_name":"Đại lý Phước Lộc","items":[{"name":"HD-1041","amount":4300000},{"name":"HD-1047","amount":2900000}],"total":7200000}
  ]~', vD);
  -- A, B, C lần lượt chiếm các máy nhanh nhất; sau khi A xong, máy IJ01 được giải phóng cho D
  pkg_seed.run_print(vA, 1, 5, 6);
  pkg_seed.run_print(vB, 2, 4, 4);
  pkg_seed.run_print(vC, 1, 3, 5);
  pkg_print_ops.finish_job(vA);
  pkg_print_ops.finish_job(vB);
  pkg_print_ops.finish_job(vC);
  pkg_seed.run_print(vD, 2, 0, 2);
  -- Giao dịch ngân hàng mô phỏng (giờ = số giờ sau khi in)
  pkg_seed.pay(vA, 1, 'FT26111500001', 26);
  pkg_seed.pay(vA, 2, 'FT26111500002', 50);
  pkg_seed.pay(vA, 3, 'FT26111500003', 30);
  pkg_seed.pay(vA, 4, 'FT26111600004', 100);
  pkg_seed.pay(vA, 5, 'FT26111600005', 40, -100000);     -- chuyển thiếu tiền -> AMOUNT_DIFF
  pkg_seed.pay(vB, 1, 'FT26111700006', 3);
  pkg_seed.pay(vB, 2, 'FT26111700007', 20);
  pkg_seed.pay(vB, 3, 'FT26111700008', 5);
  pkg_seed.pay(vC, 1, 'FT26111800009', 10);
  pkg_seed.pay(vC, 2, 'FT26111800010', 24);
  pkg_seed.pay(vC, 3, 'FT26111900011', 48);
  pkg_vietqr.reconcile_payment('FT26111900099', 'CHUYEN TIEN TRA NO', 1500000,
                               SYSTIMESTAMP - INTERVAL '1' DAY, 'NGUYEN VAN A', NULL, v_status);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Da nap du lieu mau. Trang thai giao dich cuoi: ' || v_status);
END;
DROP PACKAGE pkg_seed;
