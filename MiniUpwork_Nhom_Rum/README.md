# Mini-Upwork · Nhóm Rum

Bản Phase 3–4 chung của Đạt, Sâm và Huy. Ứng dụng kết nối PostgreSQL cục bộ và dùng phiên đăng nhập theo tài khoản. Dữ liệu giống tình huống làm việc thật nhưng toàn bộ tên, công ty và nội dung là giả lập cho đồ án. [Thiết kế gốc của nhóm](https://github.com/Ly-Dat-NT/Mini-Upwork-Distributed-Database/tree/2fc16ef9d3b4dc12bbd2bdc2941964d522871f5d)

## Mở trên Windows

1. Giải nén cả thư mục và bấm đúp `MO_MINIUPWORK_RUM.cmd`. Trên máy Đạt, file dùng Python và các thư viện Lab 2 đã có. Nếu thư mục cũ trên ổ D có `.env`, bộ chạy lấy thông tin đăng nhập PostgreSQL từ đó để tạo CSDL riêng `miniupwork_nhom_rum`.
2. Khi thấy `Uvicorn running`, mở [Mini-Upwork nhóm Rum](http://127.0.0.1:8016/). Giữ cửa sổ lệnh mở khi sử dụng.
3. Đăng nhập `user01` bằng mật khẩu Đạt đã chọn. Đây là tài khoản **Nguyễn Minh An**, một freelancer có sẵn hai hợp đồng để xem. Tài khoản khách hàng dùng để thử luồng ký quỹ là `user36`, mật khẩu `RumClient36!Demo`. Mật khẩu tài khoản ứng dụng khác với mật khẩu PostgreSQL.

CSDL được nạp lần đầu, sau đó dùng lại khi bấm mở ứng dụng. Trang chính hiển thị 10 công việc hiện đang tuyển trong 50 tin được quản lý theo trạng thái.

Sau khi cập nhật file, đóng ứng dụng đang chạy rồi mở lại bằng `MO_MINIUPWORK_RUM.cmd` để nâng lược đồ lên phiên bản 3. Trang **Quản lý** có hồ sơ, tin tuyển dụng, đề xuất và kỹ năng theo vai trò. Xem [đối chiếu báo cáo Word và sơ đồ](DOI_CHIEU_WORD_VA_SO_DO.md) để biết các luồng đã sửa.

### Chạy trên máy khác

Tạo môi trường Python trong thư mục giải nén, cài thư viện rồi bấm `MO_MINIUPWORK_RUM.cmd` hoặc chạy `run_local.py` bằng Python của môi trường. Lần đầu, nhập cổng, tài khoản và mật khẩu PostgreSQL trong cửa sổ lệnh. Tài khoản PostgreSQL cần quyền tạo database. Bạn có thể chép `.env.example` thành `.env` để lưu cấu hình cục bộ.

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe run_local.py
```

Để chạy toàn bộ phần dựng lược đồ, nâng cấp và phân quyền, dùng `run_local.py` hoặc file `.cmd` của gói. Các script `01_schema.sql` đến `04_seed_rum.sql` dựng dữ liệu ban đầu; `07_phase12_upgrade.sql` và `09_report_alignment.sql` được trình khởi động áp dụng theo phiên bản hiện tại. Không nạp lại các script tạo dữ liệu vào database đang dùng.

## Bộ dữ liệu

| Hạng mục | Số lượng |
| --- | --- |
| Tài khoản | 50 |
| Khách hàng từng đăng việc | 15 |
| Freelancer | 35 |
| Danh mục | 10 |
| Tin công việc | 50 |
| Tin đang mở | 10 |
| Đề xuất ban đầu | 112 |
| Hợp đồng | 12 |

## Trình bày Phase 3–4

- **Đạt** · `user01` lọc công việc, chọn **Xây trang đặt lịch cho phòng khám nha khoa** (`#1`), gửi một đề xuất rồi thử gửi lại để minh họa ràng buộc trùng. `sql/05_queries.sql` có Q1–Q4 cho phần tìm việc và đề xuất.
- **Sâm** · Giải thích cách ghép giao diện, FastAPI và PostgreSQL, khóa của các bảng chung, Q5–Q7 và view `miniupwork.rating_summary`. `sql/06_verify.sql` kiểm tra số lượng và các ràng buộc trên dữ liệu mới nạp.
- **Huy** · Ở **Hợp đồng**, `user01` thấy cả hợp đồng trọn gói `#1` và hợp đồng theo giờ `#2`. Dùng `user36` bấm **Giải ngân** hoặc **Thanh toán hóa đơn** để tạo giao dịch đang chờ. Trong **Lịch sử thanh toán**, bấm **Xác nhận thanh toán** hoặc **Ghi nhận thất bại**. Với mốc thứ hai của hợp đồng `#1`, bấm **Ký quỹ** rồi **Xác nhận ký quỹ**, sau đó dùng `user01` gửi bàn giao và `user36` duyệt, giải ngân. Q8–Q11 phục vụ mốc quá hạn, giờ chưa lập hóa đơn, đối soát và doanh thu theo kỳ.

Thanh toán trong ứng dụng được ghi vào sổ giao dịch giả lập trong PostgreSQL. Hai người dùng hợp đồng có quyền xem chung, còn từng thao tác ghi nhận tuân theo vai trò khách hàng hoặc freelancer. Tài khoản ứng dụng và mật khẩu chỉ dùng cho máy chạy demo cục bộ.

Đã kiểm chứng trên Chrome và PostgreSQL 18.7 với CSDL thử riêng. Đã chạy 11 truy vấn, đăng nhập và đăng xuất, gửi đề xuất và chặn gửi trùng, chặn người ngoài hợp đồng, giải ngân hai mốc và thanh toán hóa đơn 7 giờ. Mở lại ứng dụng giữ các bản ghi đã tạo.
