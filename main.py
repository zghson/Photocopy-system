# [SEG] Khởi tạo ứng dụng FastAPI và pool kết nối Oracle
import array
import datetime
import io
import json
import os

import oracledb
import qrcode
from fastapi import Body, FastAPI, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

pool = oracledb.create_pool(
    user=os.getenv("DB_USER", "PRINTRQ"),
    password=os.getenv("DB_PASSWORD", "PrintQR#2026"),
    dsn=os.getenv("DB_DSN", "localhost:1521/FreePDB1"),
    min=1, max=5, increment=1,
)
app = FastAPI(title="PrintQR API")

# [SEG] Hàm tiện ích: truy vấn SELECT và gọi khối PL/SQL
def query(sql: str, params: dict | None = None) -> list[dict]:
    """Chạy SELECT, trả về danh sách dict với tên cột viết thường."""
    with pool.acquire() as conn, conn.cursor() as cur:
        cur.execute(sql, params or {})
        cols = [c[0].lower() for c in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


def plsql(block: str, params: dict | None = None, outs: dict | None = None,
          clobs: tuple = ()) -> dict:
    """Chạy khối PL/SQL, commit nếu thành công, rollback và trả HTTP 400 nếu Oracle báo lỗi."""
    with pool.acquire() as conn, conn.cursor() as cur:
        out_vars = {name: cur.var(typ) for name, typ in (outs or {}).items()}
        if clobs:
            cur.setinputsizes(**{name: oracledb.DB_TYPE_CLOB for name in clobs})
        try:
            cur.execute(block, {**(params or {}), **out_vars})
            conn.commit()
        except oracledb .DatabaseError as exc:
            conn.rollback()
            raise HTTPException(status_code=400, detail=exc.args[0].message.split("\n")[0])
        return {name: var.getvalue() for name, var in out_vars.items()}

# [SEG] API danh mục và đơn hàng
@app.get("/api/customers")
def customers():
    return query("SELECT customer_id, customer_code, customer_name FROM customers ORDER BY 1")


@app.get("/api/templates")
def templates(customer_id: int):
    return query("""SELECT template_id, template_name FROM templates
                     WHERE customer_id = :c ORDER BY template_id""", {"c": customer_id})


class OrderIn(BaseModel):
    customer_id: int
    template_id: int
    quantity: int
    due_days: int = 7


@app.post("/api/orders")
def create_order(body: OrderIn):
    return plsql(
        "BEGIN pkg_print_ops.create_order_with_job(:c, :t, :q, TRUNC(SYSDATE) + :d, NULL, :oid, :jid); END;",
        {"c": body.customer_id, "t": body.template_id, "q": body.quantity, "d": body.due_days},
        outs={"oid": int, "jid": int},
    )

# [SEG] API lệnh in: nhập dữ liệu JSON, sinh VietQR, gán máy, in, hoàn tất
@app.get("/api/jobs")
def jobs():
    return query("""
        SELECT j.job_id, j.job_code, o.order_code, c.customer_name, j.status, j.quantity,
               j.printed_count, pkg_print_ops.job_progress(j.job_id) AS progress,
               m.machine_name, pkg_print_ops.estimate_minutes(j.job_id) AS eta_minutes,
               pkg_print_ops.collection_rate(o.order_id) AS collection_pct
          FROM print_jobs j
          JOIN orders o ON o.order_id = j.order_id
          JOIN customers c ON c.customer_id = o.customer_id
          LEFT JOIN machines m ON m.machine_id = j.machine_id
         ORDER BY j.job_id DESC""")


@app.post("/api/jobs/{job_id}/import")
def import_records(job_id: int, records: list[dict] = Body(...)):
    return plsql("BEGIN pkg_print_ops.import_records(:j, :data, :n); END;",
                 {"j": job_id, "data": json.dumps(records, ensure_ascii=False)},
                 outs={"n": int}, clobs=("data",))


@app.post("/api/jobs/{job_id}/qr")
def generate_qr(job_id: int):
    return plsql("BEGIN pkg_vietqr.generate_qr_for_job(:j, :n); END;", {"j": job_id}, outs={"n": int})


@app.post("/api/jobs/{job_id}/assign")
def assign(job_id: int, operator_id: int):
    return plsql("BEGIN pkg_print_ops.assign_machine(:j, :op, :m); END;",
                 {"j": job_id, "op": operator_id}, outs={"m": int})


@app.post("/api/jobs/{job_id}/start")
def start(job_id: int):
    return plsql("BEGIN pkg_print_ops.start_job(:j); END;", {"j": job_id})


@app.post("/api/jobs/{job_id}/print")
def print_batch(job_id: int, batch: int = 100):
    return plsql("BEGIN pkg_print_ops.print_batch(:j, :b, :n); END;",
                 {"j": job_id, "b": batch}, outs={"n": int})


@app.post("/api/jobs/{job_id}/finish")
def finish(job_id: int):
    return plsql("BEGIN pkg_print_ops.finish_job(:j); END;", {"j": job_id})


@app.get("/api/jobs/{job_id}/records")
def records(job_id: int):
    return query("""
        SELECT r.seq_no, r.recipient_name, r.amount, r.print_status, q.qr_ref, q.status AS qr_status,
               r.variable_data AS data
          FROM print_records r LEFT JOIN vietqr_codes q ON q.record_id = r.record_id
         WHERE r.job_id = :j ORDER BY r.seq_no""", {"j": job_id})

# [SEG] Ảnh mã VietQR và webhook đối soát thanh toán
@app.get("/api/qr/{qr_ref}.png")
def qr_image(qr_ref: str):
    rows = query("SELECT qr_payload FROM vietqr_codes WHERE qr_ref = :r", {"r": qr_ref})
    if not rows:
        raise HTTPException(status_code=404, detail="Khong tim thay ma QR")
    img = qrcode.make(rows[0]["qr_payload"], error_correction=qrcode.constants.ERROR_CORRECT_M)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    return StreamingResponse(buf, media_type="image/png")


class BankWebhook(BaseModel):
    transaction_id: str
    content: str
    amount: int
    payer_name: str = ""


@app.post("/api/webhook/bank")
def bank_webhook(body: BankWebhook):
    now = datetime.datetime.now()
    res = plsql(
        "BEGIN pkg_vietqr.reconcile_payment(:t, :c, :a, :at, :p, :raw, :st); END;",
        {"t": body.transaction_id, "c": body.content, "a": body.amount, "at": now,
         "p": body.payer_name, "raw": body.model_dump_json()},
        outs={"st": str}, clobs=("raw",),
    )
    return {"match_status": res["st"]}

# [SEG] Tìm kiếm ngữ nghĩa bằng VECTOR_DISTANCE
_model = None


def embed(text: str) -> array.array:
    """Nạp mô hình ở lần gọi đầu tiên, trả vector float32 đã chuẩn hóa."""
    global _model
    if _model is None:
        from sentence_transformers import SentenceTransformer
        _model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
    return array.array("f", _model.encode(text, normalize_embeddings=True))


@app.get("/api/search/templates")
def search_templates(q: str, top: int = 3):
    return query("""
        SELECT t.template_id, t.template_name, c.customer_name,
               ROUND(VECTOR_DISTANCE(t.template_embedding, :qv, COSINE), 4) AS distance
          FROM templates t JOIN customers c ON c.customer_id = t.customer_id
         WHERE t.template_embedding IS NOT NULL
         ORDER BY distance FETCH FIRST :top ROWS ONLY""", {"qv": embed(q), "top": top})


@app.get("/api/recommend/products")
def recommend_products(q: str, top: int = 3):
    return query("""
        SELECT product_code, product_name, unit_price,
               ROUND(VECTOR_DISTANCE(product_embedding, :qv, COSINE), 4) AS distance
          FROM products WHERE product_embedding IS NOT NULL
         ORDER BY distance FETCH FIRST :top ROWS ONLY""", {"qv": embed(q), "top": top})

# [SEG] Báo cáo tổng hợp từ các view window function và phục vụ giao diện tĩnh
@app.get("/api/dashboard")
def dashboard():
    return {
        "machines": query("SELECT * FROM vw_machine_ranking ORDER BY printed_rank"),
        "daily": query("SELECT * FROM vw_daily_collection ORDER BY pay_date"),
        "customers": query("SELECT * FROM vw_customer_revenue ORDER BY revenue_rank"),
    }


@app.get("/")
def index():
    return FileResponse(os.path.join(os.path.dirname(__file__), "static", "index.html"))


app.mount("/static", StaticFiles(directory=os.path.join(os.path.dirname(__file__), "static")), name="static")