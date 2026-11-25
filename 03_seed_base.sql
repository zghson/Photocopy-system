-- [SEG] Dữ liệu danh mục: khách hàng và tài khoản nhận tiền
INSERT INTO customers (customer_id, customer_code, customer_name, customer_type, tax_code, email, phone, address, brand_profile) VALUES
(1, 'KH001', 'Trung tâm Anh ngữ Sao Mai', 'CORPORATE', '0312345678', 'ketoan@saomai.edu.vn', '02838221234', 'Quận 3, TP. Hồ Chí Minh',
 '{"industry":"education","brand_colors":["#0B5ED7","#FFC107"],"logo":"saomai_logo.svg","contacts":[{"name":"Lê Thu Hà","role":"Kế toán","phone":"0903111222"}],"invoice_note":"Học phí đóng trước ngày 10 hằng tháng"}');
INSERT INTO customers (customer_id, customer_code, customer_name, customer_type, tax_code, email, phone, address, brand_profile) VALUES
(2, 'KH002', 'Phòng khám Đa khoa An Tâm', 'CORPORATE', '0398765432', 'thungan@antam.vn', '02838995566', 'Quận Bình Thạnh, TP. Hồ Chí Minh',
 '{"industry":"healthcare","brand_colors":["#198754"],"logo":"antam_logo.svg","contacts":[{"name":"Nguyễn Văn Phúc","role":"Thu ngân","phone":"0903222333"}],"invoice_note":"Quý khách vui lòng giữ phiếu để đối chiếu"}');
INSERT INTO customers (customer_id, customer_code, customer_name, customer_type, tax_code, email, phone, address, brand_profile) VALUES
(3, 'KH003', 'Công ty TNHH Sự kiện Hoàng Gia', 'CORPORATE', '0301122334', 'info@hoanggia-events.vn', '02839112233', 'Quận 1, TP. Hồ Chí Minh',
 '{"industry":"events","brand_colors":["#6F42C1","#D4AF37"],"logo":"hoanggia_logo.svg","contacts":[{"name":"Trần Bảo Ngọc","role":"Trưởng dự án","phone":"0903444555"}]}');
INSERT INTO customers (customer_id, customer_code, customer_name, customer_type, tax_code, email, phone, address, brand_profile) VALUES
(4, 'KH004', 'Công ty Phân phối Nông sản Xanh', 'CORPORATE', '0305566778', 'congno@nongsanxanh.vn', '02838776655', 'TP. Thủ Đức, TP. Hồ Chí Minh',
 '{"industry":"distribution","brand_colors":["#2E7D32"],"logo":"nongsanxanh_logo.svg","contacts":[{"name":"Phạm Thị Lụa","role":"Kế toán công nợ","phone":"0903666777"}],"invoice_note":"Thanh toán trong 15 ngày kể từ ngày nhận thông báo"}');

INSERT INTO bank_accounts (account_id, customer_id, bank_bin, bank_name, account_no, account_name, is_default) VALUES
(1, 1, '970436', 'Vietcombank', '0071001234567',  'TRUNG TAM ANH NGU SAO MAI', 1);
INSERT INTO bank_accounts (account_id, customer_id, bank_bin, bank_name, account_no, account_name, is_default) VALUES
(2, 2, '970422', 'MB Bank', '0123456789012', 'PHONG KHAM DA KHOA AN TAM', 1);
INSERT INTO bank_accounts (account_id, customer_id, bank_bin, bank_name, account_no, account_name, is_default) VALUES
(3, 3, '970407', 'Techcombank', '19036789012345', 'CONG TY TNHH SU KIEN HOANG GIA', 1);
INSERT INTO bank_accounts (account_id, customer_id, bank_bin, bank_name, account_no, account_name, is_default) VALUES
(4, 4, '970416', 'ACB', '123456789', 'CONG TY PHAN PHOI NONG SAN XANH', 1);
INSERT INTO bank_accounts (account_id, customer_id, bank_bin, bank_name, account_no, account_name, is_default) VALUES
(5, 1, '970418', 'BIDV', '31410001234567', 'TRUNG TAM ANH NGU SAO MAI', 0);

-- [SEG] Dữ liệu danh mục: nhân viên và máy in
INSERT INTO employees (employee_id, employee_code, full_name, role, hire_date, phone) VALUES (1, 'NV001', 'Trần Văn Khoa', 'OPERATOR', DATE '2022-03-01', '0911000001');
INSERT INTO employees (employee_id, employee_code, full_name, role, hire_date, phone) VALUES (2, 'NV002', 'Lê Thị Mai', 'OPERATOR', DATE '2023-06-15', '0911000002');
INSERT INTO employees (employee_id, employee_code, full_name, role, hire_date, phone) VALUES (3, 'NV003', 'Phạm Quốc Bảo', 'DESIGNER', DATE '2021-09-10', '0911000003');
INSERT INTO employees (employee_id, employee_code, full_name, role, hire_date, phone) VALUES (4, 'NV004', 'Nguyễn Hồng Nhung', 'QC', DATE '2022-11-20', '0911000004');
INSERT INTO employees (employee_id, employee_code, full_name, role, hire_date, phone) VALUES (5, 'NV005', 'Đỗ Minh Tuấn', 'MANAGER', DATE '2020-01-05', '0911000005');

INSERT INTO machines (machine_id, machine_code, machine_name, machine_type, speed_ppm, status, install_date, spec) VALUES
(1, 'MAY-IJ01', 'Máy in phun cuộn tốc độ cao IJ-1000', 'INKJET', 200, 'IDLE', DATE '2024-01-15',
 '{"max_width_mm":320,"resolution_dpi":1200,"variable_data":true,"color":"CMYK"}');
INSERT INTO machines (machine_id, machine_code, machine_name, machine_type, speed_ppm, status, install_date, spec) VALUES
(2, 'MAY-LS01', 'Máy in laser LS-500', 'LASER', 100, 'IDLE', DATE '2023-05-20',
 '{"max_width_mm":330,"resolution_dpi":1200,"variable_data":true,"color":"CMYK"}');
INSERT INTO machines (machine_id, machine_code, machine_name, machine_type, speed_ppm, status, install_date, spec) VALUES
(3, 'MAY-DP01', 'Máy in kỹ thuật số DP-300', 'DIGITAL_PRESS', 120, 'IDLE', DATE '2023-11-02',
 '{"max_width_mm":364,"resolution_dpi":2400,"variable_data":true,"color":"CMYK+spot"}');
INSERT INTO machines (machine_id, machine_code, machine_name, machine_type, speed_ppm, status, install_date, spec) VALUES
(4, 'MAY-LS02', 'Máy in laser LS-300', 'LASER', 60, 'MAINTENANCE', DATE '2021-08-12',
 '{"max_width_mm":297,"resolution_dpi":600,"variable_data":false,"color":"mono"}');

-- [SEG] Dữ liệu danh mục: sản phẩm và mẫu in
INSERT INTO products (product_id, product_code, product_name, category, description, unit_price, spec) VALUES
(1, 'SP-INV-A5', 'Phiếu thu / hóa đơn cá nhân hóa kèm VietQR', 'INVOICE',
 'Phiếu thu, hóa đơn, thông báo thanh toán in theo từng người nhận, mỗi tờ có mã VietQR riêng chứa số tiền và nội dung chuyển khoản', 450,
 '{"paper":{"type":"couche","gsm":120},"size":"A5","finishing":["cắt thành phẩm"]}');
INSERT INTO products (product_id, product_code, product_name, category, description, unit_price, spec) VALUES
(2, 'SP-INVITE', 'Thư mời cá nhân hóa', 'INVITATION',
 'Thư mời, thiệp mời in tên khách mời, kèm mã QR đăng ký hoặc đóng phí tham dự', 3500,
 '{"paper":{"type":"mỹ thuật","gsm":250},"size":"A5","finishing":["cán màng mờ","ép kim"]}');
INSERT INTO products (product_id, product_code, product_name, category, description, unit_price, spec) VALUES
(3, 'SP-CARD', 'Thẻ thành viên cá nhân hóa', 'MEMBER_CARD',
 'Thẻ hội viên, thẻ học viên in họ tên, mã định danh và mã QR', 5200,
 '{"paper":{"type":"PVC","gsm":0},"size":"CR80","finishing":["cán bóng"]}');
INSERT INTO products (product_id, product_code, product_name, category, description, unit_price, spec) VALUES
(4, 'SP-VOUCHER', 'Voucher mã QR', 'VOUCHER',
 'Phiếu giảm giá, phiếu quà tặng có mã duy nhất cho từng khách hàng', 900,
 '{"paper":{"type":"couche","gsm":250},"size":"DL","finishing":["cắt thành phẩm"]}');
INSERT INTO products (product_id, product_code, product_name, category, description, unit_price, spec) VALUES
(5, 'SP-LABEL', 'Tem nhãn mã QR', 'LABEL',
 'Tem dán sản phẩm in mã QR truy xuất nguồn gốc, mỗi tem một mã', 150,
 '{"paper":{"type":"decal","gsm":90},"size":"50x30mm","finishing":["bế tem"]}');

INSERT INTO templates (template_id, customer_id, product_id, template_name, description, layout) VALUES
(1, 1, 1, 'Phiếu thu học phí A5',
 'Phiếu thu học phí khổ A5 in tên học viên, lớp, kỳ học phí và các khoản thu; mã VietQR thanh toán ở góc phải dưới',
 '{"page":{"size":"A5","orientation":"portrait"},"fields":[{"name":"full_name","x":20,"y":30,"font":"Arial","size":12},{"name":"class","x":20,"y":40,"font":"Arial","size":11},{"name":"period","x":20,"y":50,"font":"Arial","size":11},{"name":"items","type":"table","x":20,"y":65}],"qr":{"x":120,"y":170,"size_mm":35,"error_correction":"M"}}');
INSERT INTO templates (template_id, customer_id, product_id, template_name, description, layout) VALUES
(2, 2, 1, 'Phiếu tạm ứng viện phí',
 'Phiếu tạm ứng viện phí khổ A5 in họ tên bệnh nhân, mã hồ sơ, dịch vụ khám và số tiền; mã VietQR để thanh toán không dùng tiền mặt',
 '{"page":{"size":"A5","orientation":"portrait"},"fields":[{"name":"full_name","x":20,"y":30,"font":"Arial","size":12},{"name":"patient_id","x":20,"y":40,"font":"Arial","size":11},{"name":"service","x":20,"y":50,"font":"Arial","size":11},{"name":"items","type":"table","x":20,"y":65}],"qr":{"x":120,"y":170,"size_mm":35,"error_correction":"M"}}');
INSERT INTO templates (template_id, customer_id, product_id, template_name, description, layout) VALUES
(3, 3, 2, 'Thư mời hội nghị khách hàng',
 'Thư mời hội nghị khách hàng khổ A5 in tên khách mời, chức danh, đơn vị; mã VietQR thu phí tham dự',
 '{"page":{"size":"A5","orientation":"landscape"},"fields":[{"name":"full_name","x":30,"y":45,"font":"Times New Roman","size":16},{"name":"title","x":30,"y":55,"font":"Times New Roman","size":12},{"name":"company","x":30,"y":62,"font":"Times New Roman","size":12}],"qr":{"x":150,"y":100,"size_mm":30,"error_correction":"Q"}}');
INSERT INTO templates (template_id, customer_id, product_id, template_name, description, layout) VALUES
(4, 4, 1, 'Thông báo công nợ đại lý',
 'Thông báo công nợ cuối tháng cho đại lý, liệt kê hóa đơn tồn và tổng số tiền cần thanh toán qua VietQR',
 '{"page":{"size":"A5","orientation":"portrait"},"fields":[{"name":"full_name","x":20,"y":30,"font":"Arial","size":12},{"name":"dealer_code","x":20,"y":40,"font":"Arial","size":11},{"name":"items","type":"table","x":20,"y":55}],"qr":{"x":120,"y":170,"size_mm":35,"error_correction":"M"}}');
INSERT INTO templates (template_id, customer_id, product_id, template_name, description, layout) VALUES
(5, 1, 3, 'Thẻ học viên có mã QR',
 'Thẻ học viên in họ tên, mã học viên, lớp học và mã QR dùng để điểm danh',
 '{"page":{"size":"CR80","orientation":"landscape"},"fields":[{"name":"full_name","x":10,"y":25,"font":"Arial","size":10},{"name":"student_id","x":10,"y":33,"font":"Arial","size":9},{"name":"class","x":10,"y":40,"font":"Arial","size":9}],"qr":{"x":55,"y":20,"size_mm":22,"error_correction":"H"}}');

-- [SEG] Đặt lại bộ đếm IDENTITY sau khi chèn dữ liệu với khóa chính tường minh
BEGIN
  FOR t IN (SELECT table_name, column_name FROM user_tab_identity_cols) LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE ' || t.table_name || ' MODIFY ' || t.column_name ||
      ' GENERATED BY DEFAULT ON NULL AS IDENTITY (RESTART START WITH LIMIT VALUE)';
  END LOOP;
END;

COMMIT;
