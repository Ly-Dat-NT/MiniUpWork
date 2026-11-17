# Đối chiếu Mini-Upwork nhóm Rum với báo cáo và sơ đồ

Đối chiếu thư mục đang dùng trên ổ D với `Project_Report_DB (2).docx` và sáu ảnh `1.png`, `d1 (1).png`, `d2v2 (1).png`, `Schema1.png`, `Schema2.png`, `Schema3.png`. Báo cáo §2.1.2 xác định sơ đồ EER tổng quan là chuẩn khái niệm. Dùng §2.2–2.5 để giải quyết những chỗ các hình đặt tên hoặc vẽ khóa khác nhau.

## Phần đã có ở bản trên ổ D

- Tài khoản có thể mang một hoặc cả hai vai trò, kỹ năng độc lập và liên kết với freelancer hoặc tin đăng. Tin và hợp đồng tách hai loại trọn gói và theo giờ. Một cặp freelancer–tin có một đề xuất, một tin có tối đa một đề xuất được nhận.
- Bản trọn gói đã có mốc và ký quỹ. Bản theo giờ đã có ghi giờ, giới hạn giờ, chặn chồng lấn và hóa đơn tuần. Giao dịch tham chiếu đúng một trong hai nguồn, có người trả và người nhận, và có giao dịch bù liên kết giao dịch gốc.
- Đánh giá từ hai bên đã giới hạn theo hợp đồng hoàn thành. Phase 3 đã có dữ liệu mẫu, 11 truy vấn và các trigger/view. Phase 4 đã kết nối giao diện với PostgreSQL qua FastAPI.

## Phần lệch, lỗi hoặc thiếu đã xử lý

| Mục đối chiếu | Bản trước | Bản cập nhật |
| --- | --- | --- |
| Hồ sơ khách hàng và freelancer · UR-C01, UR-F01 · `1.png`, `Schema1.png` | Chỉ tạo lúc đăng ký. Thiếu địa chỉ thanh toán và mức kinh nghiệm. | Thêm biểu mẫu sửa hồ sơ theo vai trò trong **Quản lý**. Địa chỉ thanh toán chỉ có trong hồ sơ riêng. |
| Tin và danh mục · FR-03–04 · `d1 (1).png`, `Schema2.png` | Biểu mẫu chỉ chọn một kỹ năng. Lọc theo khóa danh mục chính xác, bỏ qua danh mục con. | Một tin có thể chọn nhiều kỹ năng và mức yêu cầu riêng. Lọc danh mục cha bao gồm các danh mục con. |
| Đề xuất và hợp đồng · UR-F03, BR-11, BR-19, BR-21–23 | Nộp lại dùng giá và thư cũ. Màn hình tự dựng một mốc sau 7 ngày hoặc chọn 20 giờ mỗi tuần. | Sửa đề xuất khi đang gửi và sửa nội dung khi nộp lại, giữ nguyên mã đề xuất. Khách chọn các mốc, hạn và số tiền hoặc giới hạn tuần. Nếu giá đã thay đổi trước khi bấm lưu, khách cần tải lại đề xuất. |
| Ký quỹ, mốc · BR-24, BR-30–31 và §2.5 | Thiếu hủy ký quỹ đang chờ. Có thể hoàn thẳng ở mốc đã bàn giao hoặc đã duyệt. | Tạo, xác nhận hoặc hủy ký quỹ đang chờ. Mốc đã bàn giao có thể được yêu cầu sửa để trở về **Đã ký quỹ** rồi hoàn. Mốc đã duyệt đi tiếp sang giải ngân. Có thời điểm giải ngân riêng `released_at`. |
| Sổ giao dịch · BR-32–37 và §2.5 | Chỉ có giao dịch thành công, không thể ghi nhận đang chờ hoặc thất bại. | Tạo giao dịch đang chờ, rồi xác nhận thành công hoặc thất bại. Thất bại giữ lịch sử và cho phép thử lại. Chỉ thành công mới giải ngân mốc, đánh dấu đã trả hóa đơn và được tính vào Q10–Q11. Giao dịch đã thành công được sửa sai bằng bút toán bù. |
| Hóa đơn theo giờ · BR-25–29 · `d2v2 (1).png`, `Schema3.png` | Mở lại hóa đơn sau tranh chấp nhưng không loại được giờ đã gắn vào hóa đơn đó. | Loại giờ khi hóa đơn đã mở lại thành nháp, tính lại tổng, và chỉ lập hóa đơn khi còn giờ đủ điều kiện. View `weekly_invoice_summary` hiện tổng giờ và tổng tiền. |
| Đánh giá · BR-38–42 | Buộc có nhận xét. View sinh cả dòng 0 đánh giá và thiếu thời điểm cập nhật. | Nhận xét tùy chọn. View `rating_summary` chỉ có dòng khi người dùng đã nhận đánh giá hợp lệ, kèm `updated_at`. Hồ sơ chưa được đánh giá vẫn mở được và hiển thị số lượt bằng 0. |

## Phần chênh giữa các sơ đồ và phần bổ sung kỹ thuật

- `Schema1.png` đặt `freelancer_id` trong Skill, còn `Schema2.png` và báo cáo §2.2 dùng bảng liên kết `freelancer_skill`. Bản chạy dùng bảng liên kết và danh mục kỹ năng chung để một kỹ năng dùng được cho nhiều freelancer và tin.
- Các tên `Payment_Contract` và `Payment_transaction` trong hình cùng đi vào một sổ `payment_transaction` theo quy tắc nguồn loại trừ BR-33. Đánh giá lưu cả người đánh giá lẫn người nhận như EER tổng quan. `rating_summary` và các tổng hóa đơn được tính từ dữ liệu gốc qua view.
- `app_user.username`, `app_session`, tài khoản PostgreSQL giới hạn quyền và bảng theo dõi phiên bản hỗ trợ đăng nhập bằng `user01`, vận hành và nâng cấp. `job_type` và `contract_type` hỗ trợ kiểm tra đúng một kiểu con. Giới hạn giờ 20 vẫn là giá trị dự phòng cho lời gọi API cũ, còn biểu mẫu tạo hợp đồng yêu cầu khách điền.
- Các thao tác trở lại hợp đồng đang làm, mở hóa đơn tranh chấp thành bản nháp và ký quỹ lại sau hoàn được giữ như quy trình xử lý tiếp. Mỗi lần ký quỹ hoặc thanh toán trước đó vẫn có trong lịch sử.
- Tiền thanh toán là dữ liệu mô phỏng bằng USD. Báo cáo §1.1.4 đặt ngân hàng thật, nhắn tin, lưu tệp và giám sát màn hình ngoài phạm vi.

## Nâng cấp và kiểm thử

Đóng cửa sổ đang chạy website rồi mở lại `MO_MINIUPWORK_RUM.cmd` sau khi đã cập nhật các file. Trình chạy áp dụng `09_report_alignment.sql` để chuyển schema từ 2 lên 3 trong một giao dịch. Các khoản thanh toán cũ được gắn trạng thái `SUCCEEDED` dựa trên cách bản trước chỉ ghi sổ khi đã thanh toán. Giữ tài khoản, tin, đề xuất, hợp đồng và mã giao dịch đã có.

Kiểm thử thực hiện trên PostgreSQL 18.7 và Chrome với CSDL riêng. Đã đối chiếu dữ liệu trước và sau nâng cấp, chạy 11 truy vấn, kiểm tra phân quyền, sao lưu và phục hồi, thử hồ sơ, tuyển dụng, ký quỹ, giao dịch thất bại và thử lại, hóa đơn và đánh giá. Bộ kiểm thử hiệu năng gồm 10.000 tin và 50.000 đề xuất.
