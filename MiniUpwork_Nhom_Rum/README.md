# Mini-Upwork · Nhóm Rum

Bản Phase 3–4 chung của Đạt, Sâm và Huy. Ứng dụng kết nối PostgreSQL cục bộ và dùng phiên đăng nhập theo tài khoản. Dữ liệu giống tình huống làm việc thật nhưng toàn bộ tên, công ty và nội dung là giả lập cho đồ án. [Thiết kế gốc của nhóm](https://github.com/Ly-Dat-NT/Mini-Upwork-Distributed-Database/tree/2fc16ef9d3b4dc12bbd2bdc2941964d522871f5d)

## Mở trên Windows

1. Giải nén cả thư mục và bấm đúp `MO_MINIUPWORK_RUM.cmd`. Trên máy Đạt, file dùng Python và các thư viện Lab 2 đã có. Nếu thư mục cũ trên ổ D có `.env`, bộ chạy lấy thông tin đăng nhập PostgreSQL từ đó để tạo CSDL riêng `miniupwork_nhom_rum`.
2. Khi thấy `Uvicorn running`, mở [Mini-Upwork nhóm Rum](http://127.0.0.1:8016/). Giữ cửa sổ lệnh mở khi sử dụng.
3. Đăng nhập bằng mật khẩu demo được cấp riêng. `user01` là tài khoản **Nguyễn Minh An** có sẵn hợp đồng để xem. `user36` là tài khoản khách hàng mẫu để thử luồng ký quỹ.

CSDL được nạp lần đầu, sau đó dùng lại khi bấm mở ứng dụng. Chế độ **Freelancer** hiển thị 10 công việc đang tuyển trong bộ dữ liệu ban đầu gồm 50 tin. Chế độ **Khách hàng** mở thẳng bảng tuyển dụng của tài khoản.

Sau khi cập nhật file, đóng ứng dụng đang chạy rồi mở lại bằng `MO_MINIUPWORK_RUM.cmd`. Trình khởi động áp dụng các bản nâng cấp PostgreSQL trong một giao dịch. Xem [đối chiếu báo cáo Word và sơ đồ](DOI_CHIEU_WORD_VA_SO_DO.md) cho phần mô hình dữ liệu và các quy tắc tính phí.

## Hồ sơ và chuyển chế độ

- Bấm **Hồ sơ của tôi** để xem thông tin tài khoản, điểm đánh giá đã nhận và hồ sơ theo vai trò. Hồ sơ freelancer có chức danh, giới thiệu, đơn giá, trạng thái nhận việc và kỹ năng. Hồ sơ khách hàng có công ty, giới thiệu và địa chỉ thanh toán riêng tư.
- Với `user01`, bấm menu tài khoản ở góc trên rồi chọn **Thêm hồ sơ khách hàng**. Điền tên công ty và bấm **Tạo hồ sơ**. Trong cùng menu, chọn **Khách hàng** hoặc **Freelancer**. Mỗi hồ sơ dùng cùng `user_id` theo FR-01, BR-02 và §2.3. Lựa chọn chế độ gần nhất được nhớ trong trình duyệt. BR-12 tiếp tục chặn việc tự gửi đề xuất vào tin do tài khoản đó đăng.
- Ở chế độ **Khách hàng**, dùng **Đăng việc** để tạo bản nháp, **Mở tin** để nhận hồ sơ và **Xem đề xuất** để xem ứng viên. Mục **Hợp đồng và thanh toán** hiển thị các hợp đồng của vai trò đang dùng. `user36` có thể mở trực tiếp chế độ khách hàng để thử với dữ liệu mẫu.
- Ở **Tuyển dụng → Đã kết thúc**, chọn **Đăng lại** trên một tin đã đóng để mở tin mới với cùng nội dung, kỹ năng và ngân sách hoặc đơn giá. Tin cũ vẫn giữ đề xuất và hợp đồng của lần tuyển trước.
- Hai banner dùng Playfair Display có dấu tiếng Việt. Các tệp font nằm trong ứng dụng để demo chạy được khi mất mạng.

### Chạy trên máy khác

Tạo môi trường Python trong thư mục giải nén, cài thư viện rồi bấm `MO_MINIUPWORK_RUM.cmd` hoặc chạy `run_local.py` bằng Python của môi trường. Lần đầu, nhập cổng, tài khoản và mật khẩu PostgreSQL trong cửa sổ lệnh. Tài khoản PostgreSQL cần quyền tạo database. Bạn có thể chép `.env.example` thành `.env` để lưu cấu hình cục bộ.

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe run_local.py
```

Để chạy toàn bộ phần dựng lược đồ, nâng cấp và phân quyền, dùng `run_local.py` hoặc file `.cmd` của gói. Các script `01_schema.sql` đến `04_seed_rum.sql` dựng dữ liệu ban đầu. Trình khởi động áp dụng các bản nâng cấp SQL đến `12_user_wallet.sql`. Dùng trình khởi động để nâng cấp database đang dùng.

Mở **Hợp đồng và thanh toán → Ví người dùng** trong cả hai chế độ. Mỗi tài khoản có một số dư và lịch sử giao dịch chung. Khách hàng có thể nạp USD mô phỏng, ký quỹ và trả hóa đơn từ ví. Freelancer nhận tiền giải ngân và tiền công theo giờ vào cùng ví. Các khoản trả cho freelancer đã hoàn tất trước khi nâng cấp được bổ sung vào lịch sử ví.

Với hợp đồng trọn gói, hai bên có thể đánh giá 1–5 sao cho từng mốc sau khi giải ngân. Freelancer có thể xem trước đối soát khi hủy sớm. Phí hủy bằng 20% giá trị hợp đồng nhân với tỷ lệ mốc chưa nghiệm thu. Hệ thống giải ngân các mốc đã nghiệm thu, khấu trừ phí từ số tiền giải ngân lần cuối và hoàn ký quỹ của mốc chưa nghiệm thu. Tiền đền vào ví người dùng của khách hàng. Freelancer có thể trả phần phí còn thiếu bằng chuyển khoản mô phỏng trong phần đối soát.

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

Mở **Hợp đồng và thanh toán**, chọn **Trọn gói** hoặc **Theo giờ** và chọn một hợp đồng. Trong mỗi hợp đồng có ba mục **Tiến độ và thanh toán**, **Hóa đơn và giao dịch**, **Đánh giá hai chiều**. Phần tìm việc, hồ sơ và chuyển chế độ dùng cùng tài khoản từ bản Đạt.

- **Trọn gói** · Mỗi mốc đi qua **Nạp ký quỹ → Nộp sản phẩm → Nghiệm thu và giải ngân → Gửi đánh giá**. Khách hàng nạp và giải ngân, freelancer xác nhận đã nộp sản phẩm. Sau khi hợp đồng hoàn thành, mỗi bên gửi một đánh giá cho bên kia. Lịch sử trọn gói gồm ký quỹ và giao dịch theo mốc.
- **Theo giờ** · Bảng chấm công và khung xem trước hóa đơn theo bố cục của Huy. Freelancer ghi giờ, chọn tuần UTC và gửi hóa đơn. Khách hàng duyệt, đối soát và xác nhận thanh toán. Hóa đơn tuần, giao dịch và đánh giá nằm trong cùng hợp đồng.
- **Phông chữ** · Source Sans 3 dùng cho nội dung, bảng và hợp đồng. Playfair Display dùng trên các banner đăng nhập và tìm việc. Font tiếng Việt được đóng gói để chạy ngoại tuyến.

- **Đạt** · `user01` lọc công việc, chọn **Xây trang đặt lịch cho phòng khám nha khoa** (`#1`), gửi một đề xuất rồi thử gửi lại để minh họa ràng buộc trùng. `sql/05_queries.sql` có Q1–Q4 cho phần tìm việc và đề xuất.
- **Sâm** · Giải thích cách ghép giao diện, FastAPI và PostgreSQL, khóa của các bảng chung, Q5–Q7 và view `miniupwork.rating_summary`. `sql/06_verify.sql` kiểm tra số lượng và các ràng buộc trên dữ liệu mới nạp.
- **Huy** · Dùng hợp đồng trọn gói #1 và hợp đồng theo giờ #2. Với mốc thứ hai của hợp đồng #1, khách hàng dùng user36 để nạp ký quỹ. Freelancer user01 bấm **Nộp sản phẩm**. Khách hàng bấm **Nghiệm thu và giải ngân**. Trong hợp đồng #2, chọn một hóa đơn ở khung xem trước hoặc mục **Hóa đơn và giao dịch** để duyệt và xác nhận thanh toán. Q8–Q11 minh họa mốc quá hạn, giờ chưa lập hóa đơn, đối soát và doanh thu.

Thanh toán trong ứng dụng được ghi vào sổ giao dịch giả lập trong PostgreSQL. Hai người dùng hợp đồng có quyền xem chung, còn từng thao tác ghi nhận tuân theo vai trò khách hàng hoặc freelancer. Tài khoản ứng dụng và mật khẩu chỉ dùng cho máy chạy demo cục bộ.

Đã kiểm chứng trên Chrome và PostgreSQL 18.7 với CSDL thử riêng. Đã chạy 11 truy vấn, đăng nhập và đăng xuất, gửi đề xuất và chặn gửi trùng, chặn người ngoài hợp đồng, giải ngân hai mốc và thanh toán hóa đơn 7 giờ. Mở lại ứng dụng giữ các bản ghi đã tạo.
