Thứ tự chạy script (UTF-8):
00_create_user.sql (SYS) -> 01_drop_all.sql -> 02_tables.sql -> 03_seed_base.sql
-> 04_pkg_vietqr.sql -> 05_pkg_print_ops.sql -> 06_triggers.sql -> 07_seed_flow.sql
-> 08_views_window.sql -> 09_queries_tables.sql -> 10_json_queries.sql
-> (python app/embed_vectors.py) -> 12_vector.sql -> 11_graph.sql
Ứng dụng: cd app && pip install -r requirements.txt && uvicorn main:app --reload
