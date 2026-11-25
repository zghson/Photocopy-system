-- [SEG] Chỉ mục vector IVF (tạo sau khi chạy embed_vectors.py để nạp embedding)
CREATE VECTOR INDEX ix_tpl_vec ON templates (template_embedding)
  ORGANIZATION NEIGHBOR PARTITIONS
  DISTANCE COSINE
  WITH TARGET ACCURACY 90;

CREATE VECTOR INDEX ix_prod_vec ON products (product_embedding)
  ORGANIZATION NEIGHBOR PARTITIONS
  DISTANCE COSINE
  WITH TARGET ACCURACY 90;

-- [SEG] Kiểm tra số chiều và độ dài (chuẩn) của vector đã lưu
SELECT template_id, template_name,
       VECTOR_DIMENSION_COUNT(template_embedding)        AS dims,
       ROUND(VECTOR_NORM(template_embedding), 4)         AS norm
  FROM templates
 WHERE template_embedding IS NOT NULL;

-- [SEG] Tìm các mẫu in tương tự một mẫu cho trước bằng khoảng cách cosine
SELECT t2.template_id, t2.template_name,
       ROUND(VECTOR_DISTANCE(t1.template_embedding, t2.template_embedding, COSINE), 4) AS cosine_distance
  FROM templates t1
  JOIN templates t2 ON t2.template_id <> t1.template_id
 WHERE t1.template_id = 1
 ORDER BY cosine_distance
 FETCH FIRST 3 ROWS ONLY;

-- [SEG] Truy vấn lai: lọc quan hệ (khách hàng, loại sản phẩm) kết hợp tìm kiếm ngữ nghĩa
-- :qv là vector câu hỏi do ứng dụng truyền vào (xem mục 3.5)
SELECT t.template_id, t.template_name, c.customer_name,
       ROUND(VECTOR_DISTANCE(t.template_embedding, :qv, COSINE), 4) AS cosine_distance
  FROM templates t
  JOIN customers c ON c.customer_id = t.customer_id
  JOIN products  p ON p.product_id  = t.product_id
 WHERE p.category = 'INVOICE'
   AND t.template_embedding IS NOT NULL
 ORDER BY cosine_distance
 FETCH APPROX FIRST 3 ROWS ONLY;

-- [SEG] (Tham khảo) Tạo embedding ngay trong cơ sở dữ liệu bằng mô hình ONNX đã nạp
-- BEGIN
--   DBMS_VECTOR.LOAD_ONNX_MODEL('DM_DUMP', 'multilingual_minilm.onnx', 'MINILM_ML',
--     JSON('{"function":"embedding","embeddingOutput":"embedding","input":{"input":["DATA"]}}'));
-- END;
-- /
-- SELECT VECTOR_EMBEDDING(MINILM_ML USING 'phiếu thu học phí có mã QR' AS data) FROM dual;
