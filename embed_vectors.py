# [SEG] Nạp mô hình học máy đa ngôn ngữ và kết nối Oracle
import array
import os

import oracledb
from sentence_transformers import SentenceTransformer

MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"   # xuất vector 384 chiều, hỗ trợ tiếng Việt
model = SentenceTransformer(MODEL_NAME)

conn = oracledb.connect(
    user=os.getenv("DB_USER", "PRINTRQ"),
    password=os.getenv("DB_PASSWORD", "PrintQR#2026"),
    dsn=os.getenv("DB_DSN", "localhost:1521/freepdb1"),
)

# [SEG] Cấu hình các bảng cần sinh vector: (bảng, khóa chính, biểu thức văn bản, cột vector)
TARGETS = [
    ("templates", "template_id", "template_name || '. ' || description", "template_embedding"),
    ("products",  "product_id",  "product_name || '. ' || description",  "product_embedding"),
]

# [SEG] Sinh embedding cho từng dòng và lưu vào cột VECTOR
with conn.cursor() as cur:
    for table, pk, text_expr, vec_col in TARGETS:
        cur.execute(f"SELECT {pk}, {text_expr} FROM {table}")
        rows = cur.fetchall()
        texts = [r[1] for r in rows]
        vectors = model.encode(texts, normalize_embeddings=True)       # chuẩn hóa độ dài về 1
        data = [(array.array("f", vec), row[0]) for vec, row in zip(vectors, rows)]
        cur.executemany(f"UPDATE {table} SET {vec_col} = :1 WHERE {pk} = :2", data)
        print(f"{table}: đã lưu {len(data)} vector {vectors.shape[1]} chiều")
conn.commit()
conn.close()
