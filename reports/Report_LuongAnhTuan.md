# REPORT LAB 16 GCP - Phương án CPU + LightGBM

**Họ tên sinh viên**: Lương Anh Tuấn

**MSSV**: 2A202600113

## Đánh giá ngắn (5-10 dòng)
Trong phương án CPU, mô hình LightGBM cho tốc độ train rất nhanh (khoảng 1.268 giây) trên instance n2-standard-8, phù hợp cho bài toán dữ liệu dạng bảng. Chất lượng dự đoán đạt mức tốt với AUC-ROC 0.958576 và Accuracy 0.998947. F1-Score 0.727273 cho thấy mô hình đã cân bằng tương đối hợp lý giữa Precision (0.655738) và Recall (0.816327) trong bài toán mất cân bằng lớp. Hiệu năng suy luận rất cao với latency 1 dòng dữ liệu khoảng 0.657 ms và throughput hơn 1.2 triệu rows/giây cho batch 1000 dòng. Lý do sử dụng CPU thay GPU là do tài khoản mới trên GCP thường bị khóa GPU quota (0), trong khi CPU instance có thể triển khai ngay, chi phí ổn định hơn và vẫn đạt được kết quả benchmark tốt cho bài toán LightGBM.
