# Đối chiếu triển khai với Phase 1 và Phase 2

Đối chiếu với đặc tả và báo cáo lược đồ tại commit `2fc16ef9d3b4dc12bbd2bdc2941964d522871f5d` của repo nhóm Rum. [Báo cáo Phase 1](https://github.com/Ly-Dat-NT/Mini-Upwork-Distributed-Database/blob/2fc16ef9d3b4dc12bbd2bdc2941964d522871f5d/docs/report/Project_Report_DB.docx) · [Báo cáo Phase 2](https://github.com/Ly-Dat-NT/Mini-Upwork-Distributed-Database/blob/2fc16ef9d3b4dc12bbd2bdc2941964d522871f5d/docs/report/Analysis%20Relational%20Schema%20Mapping%2C%20Foreign%20Key%20definitons%2C%20Normalization%20proofs.docx) · [Kế hoạch kiểm chứng](https://github.com/Ly-Dat-NT/Mini-Upwork-Distributed-Database/blob/2fc16ef9d3b4dc12bbd2bdc2941964d522871f5d/docs/implementation-plan.md)

## Luồng nghiệp vụ

| Yêu cầu | Phần bổ sung hoặc xác nhận |
| --- | --- |
| FR-01 và FR-02, BR-01–03 | Đăng ký vai trò khách hàng, freelancer hoặc cả hai trong cùng giao dịch. Email duy nhất không phân biệt hoa thường. Freelancer sửa kỹ năng và mức 1–5 trong trang **Quản lý**. |
| FR-03 và FR-04, BR-04–10 | Khách hàng tạo bản nháp có đúng một loại giá và kỹ năng, sau đó mở, đóng hoặc hủy. Tìm việc chỉ trả tin mở, lọc theo danh mục, kỹ năng, loại và khoảng giá. Giá theo giờ so theo khoảng giao nhau. |
| FR-05, BR-11–14 | Cặp freelancer–tin là duy nhất. Trigger chặn tự ứng tuyển, ứng tuyển vào tin chưa mở và sai chuyển trạng thái. Giao diện hỗ trợ rút rồi nộp lại cùng mã, khách hàng có thể chọn lọc, từ chối hoặc chấp nhận. |
| FR-06, BR-15–20 | Chấp nhận đề xuất, tạo hợp đồng nháp đúng loại, từ chối các đề xuất đang chờ khác và đóng tin trong một giao dịch. Khách hàng có thể bắt đầu, tạm dừng, tiếp tục, hoàn thành hoặc kết thúc theo trạng thái hiện tại. |
| FR-07, BR-21–24 | Mốc có số thứ tự duy nhất và tổng tiền khớp hợp đồng khi kích hoạt. Bổ sung yêu cầu sửa, hoàn ký quỹ, ký quỹ lại và hủy mốc chưa ký quỹ. |
| FR-08 và FR-09, BR-25–29 | Freelancer ghi giờ cho hợp đồng đang làm. CSDL chặn chồng giờ, vượt giới hạn tuần và giờ trước ngày bắt đầu. Hóa đơn gom giờ đủ điều kiện trong một tuần UTC bắt đầu thứ Hai. Có luồng gửi, duyệt, đối soát và mở lại. |
| FR-10, BR-30–37 | Ký quỹ đi qua `PENDING`, `FUNDED`, rồi `RELEASED` hoặc `REFUNDED`. Lưu từng lượt ký quỹ bằng USD. Sổ giao dịch kiểm tra đúng nguồn, hợp đồng, hai bên và số tiền. Người nhận có thể ghi giao dịch bù toàn phần liên kết giao dịch gốc. |
| FR-11 và FR-12, BR-38–42 | Hai bên đánh giá sau khi hoàn thành, mỗi bên một lần. View `rating_summary` tính điểm trên dữ liệu gốc. Hồ sơ công khai chỉ trả tên, chuyên môn, kỹ năng và điểm. |
| FR-13, BR-36 và BR-43 | Sổ giao dịch đã ghi có trigger bảo vệ. Khóa ngoại giữ liên kết lịch sử, và tài khoản chạy ứng dụng chỉ có quyền cần cho API. |

Giao diện nhận hợp đồng trọn gói với một mốc mặc định bằng toàn bộ giá đề xuất và hạn bảy ngày. API cho phép truyền nhiều mốc. Với hợp đồng theo giờ, giới hạn giao diện mặc định là 20 giờ/tuần và API cho phép đặt giới hạn khác. Hóa đơn và giao dịch dùng USD. Ứng dụng ghi trạng thái thanh toán giả lập vào CSDL.

## Lược đồ thống nhất và phụ thuộc hàm

| Quan hệ hoặc nhóm | Khóa và phụ thuộc chính |
| --- | --- |
| `app_user`, `client`, `freelancer` | `user_id` xác định hồ sơ. `username` và email chuẩn hóa là định danh duy nhất của tài khoản. Hai bảng vai trò dùng PK chia sẻ với `app_user`, giữ tính chuyên biệt toàn phần và chồng lấp. |
| `job`, `fixed_price_job`, `hourly_job` | `job_id` xác định chủ tin, danh mục, nội dung và trạng thái. Mỗi bảng giá dùng `job_id` làm PK/FK. `category_name` và `skill_name` nằm ở danh mục riêng. |
| `job_skill`, `freelancer_skill` | Khóa ghép lần lượt là `(job_id, skill_id)` và `(freelancer_id, skill_id)`. Mức yêu cầu hoặc mức thành thạo phụ thuộc vào cả cặp. |
| `proposal`, `contract` và hai subtype | Mã proposal và cặp `(freelancer_id, job_id)` là khóa của đề xuất. `contract_id` và `proposal_id` duy nhất xác định hợp đồng. `job_id` và hai bên của hợp đồng được suy ra qua proposal và job. Hai bảng giá hợp đồng chia sẻ `contract_id`. |
| `milestone`, `escrow_funding` | `milestone_id` và `(contract_id, sequence_no)` xác định mốc. `funding_id` xác định lượt ký quỹ. Chỉ mục duy nhất có điều kiện giới hạn một lượt còn hiệu lực trên mỗi mốc. |
| `weekly_invoice`, `time_entry` | `invoice_id` và `(contract_id, period_start)` xác định hóa đơn. `period_end` là cột sinh từ ngày đầu tuần. FK ghép bảo đảm giờ làm được gán vào hóa đơn của cùng hợp đồng. Tổng giờ và tiền được tính từ mục giờ đủ điều kiện và đơn giá hợp đồng. |
| `payment_transaction`, `review` | `payment_id` xác định bản ghi sổ. Bản ghi lưu định danh giao dịch và hai bên để đối soát, với trigger kiểm tra các trường suy ra từ nguồn. `review_id` và cặp `(contract_id, reviewer_id)` xác định đánh giá. Tổng hợp điểm là view. |

Các bảng danh mục tách tên ra khỏi quan hệ liên kết. Bảng nối giữ các thuộc tính phụ thuộc trọn khóa, bảng con giữ quan hệ 1–1 với cha qua PK/FK. Cột ngày cuối tuần sinh tự động và các trường đối chiếu trong sổ giao dịch là hai lựa chọn lưu trữ có phụ thuộc dẫn xuất được nêu rõ. Đánh giá chuẩn hóa dựa trên các phụ thuộc nghiệp vụ trong bảng trên.

## Nâng cấp CSDL đang dùng

Tắt cửa sổ chạy Mini-Upwork cũ, cập nhật mã rồi bấm `MO_MINIUPWORK_RUM.cmd`. Trình khởi động nhận diện CSDL Rum và nâng lược đồ từ phiên bản 1 lên 2 trong một giao dịch. Bộ seed chỉ chạy khi tạo bộ dữ liệu mới. Phiên bản nâng cấp giữ proposal, tài khoản, việc, hợp đồng và giao dịch đã nhập. File `.rum-runtime.json` được sinh trên máy để ứng dụng đăng nhập PostgreSQL bằng tài khoản giới hạn quyền.

## Kết quả kiểm chứng

- Nâng cấp một CSDL phiên bản 1 có thêm đề xuất, rồi chạy trình nâng cấp lần hai. Dấu vân tay dữ liệu của tài khoản, việc, đề xuất, hợp đồng và giao dịch vẫn trùng với trước khi nâng cấp. Tài khoản chạy ứng dụng không có quyền tạo đối tượng trong schema hay xóa bản ghi sổ giao dịch.
- Chạy cả 11 truy vấn. Kiểm tra qua Chrome và API gồm tài khoản hai vai trò, giấu dữ liệu đăng nhập khỏi hồ sơ công khai, kỹ năng 1–5, tin nháp, đề xuất tự ứng tuyển hoặc trùng, hoàn và ký quỹ lại, khoản bù, giờ chồng lấn, hóa đơn chỉ gồm giờ đủ điều kiện và đánh giá đúng người đúng thời điểm.
- Sao lưu CSDL thử bằng `pg_dump -Fc`, khôi phục vào database mới bằng `pg_restore --no-owner --no-privileges --exit-on-error` và so dấu vân tay của năm bảng nghiệp vụ. Mốc khôi phục được kiểm tra là các bản ghi đã commit tại thời điểm dump.
- Trên Windows x64, AMD Ryzen 7 H 255 và PostgreSQL 18.7, đo hàm tìm việc với **10.000 tin và 50.000 đề xuất**. Đo ba bộ lọc, gồm một lọc trọn gói theo từ khóa, danh mục, kỹ năng và giá, một lọc đơn giá theo giờ, và một trang 10 tin mới nhất. Thực hiện bảy lần mỗi bộ lọc. Lần chậm nhất **235,88 ms**, tính cả kết nối PostgreSQL và hai truy vấn đếm/trả trang. Có thể dựng lại bộ tải bằng `08_benchmark_fixture.sql` trên một CSDL thử riêng đã nạp đủ bộ Rum và áp dụng `07_phase12_upgrade.sql`. Kết quả này đo trên cùng máy và bộ dữ liệu giả lập đó.
