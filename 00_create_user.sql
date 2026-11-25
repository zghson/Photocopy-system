-- [SEG] Tạo schema làm việc (chạy bằng SYS/SYSTEM trong PDB, ví dụ FREEPDB1)
ALTER SESSION SET CONTAINER = FREEPDB1;

CREATE USER printqr IDENTIFIED BY "PrintQR#2026"
  DEFAULT TABLESPACE users
  QUOTA UNLIMITED ON users;

GRANT CREATE SESSION TO printqr;
GRANT DB_DEVELOPER_ROLE TO printqr;        -- bảng, view, sequence, procedure, trigger...
GRANT CREATE PROPERTY GRAPH TO printqr;    -- đồ thị thuộc tính SQL/PGQ (23ai)
