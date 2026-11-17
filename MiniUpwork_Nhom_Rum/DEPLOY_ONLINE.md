# MiniUpwork online

Địa chỉ giao diện là `https://ly-dat-nt.github.io/MiniUpWork/`. GitHub Pages phát hành HTML, CSS, JavaScript và font. FastAPI chạy trên Render và dùng một cơ sở dữ liệu PostgreSQL riêng trên Neon. Mọi trình duyệt dùng cùng API HTTPS.

## 1. Tạo cơ sở dữ liệu demo

Tạo một dự án PostgreSQL trên Neon dành riêng cho MiniUpwork. Trong **Connect**, chọn kết nối trực tiếp, tắt **Connection pooling**, rồi sao chép chuỗi kết nối của chủ cơ sở dữ liệu. Trong thư mục chứa `bootstrap_online.py`, chạy:

```powershell
python -m pip install -r requirements.txt
python bootstrap_online.py
```

Dán chuỗi kết nối vào lời nhắc ẩn, sau đó chọn hai mật khẩu riêng cho `user01` và `user02`. Lệnh dựng dữ liệu mô phỏng mới, tạo hợp đồng ba mốc giữa hai tài khoản và lưu thông tin kết nối giới hạn quyền vào `.env.render`. Chạy lại giữ các tài khoản và dữ liệu đang sử dụng. Giữ `.env.render`, `.env.hosted` và `.rum-hosted-runtime.json` trên máy.

## 2. Chạy FastAPI

Trong Render, tạo một **Blueprint** từ repo `Ly-Dat-NT/MiniUpWork`, nhánh `online-demo`, dùng `render.yaml` ở gốc. Điền `DATABASE_URL` và `DATABASE_PASSWORD` vào biến môi trường của Render từ `.env.render`. Giá trị `MINIUPWORK_WEB_URL` được cấu hình sẵn cho GitHub Pages. Sau khi triển khai, mở `/health` trên địa chỉ HTTPS Render để kiểm tra trường `database` trả về `ok`.

## 3. Phát hành giao diện

Dùng địa chỉ Render mà dashboard đã cấp để dựng bộ tệp tĩnh:

```powershell
python build_pages.py --api-url https://TEN-DICH-VU.onrender.com
```

Đưa nội dung của `pages-build` lên gốc nhánh `gh-pages`. Trong **Settings → Pages**, chọn **Deploy from a branch**, nhánh `gh-pages`, thư mục `/(root)`. Sau khi GitHub báo đã phát hành, mở trang Pages ở hai trình duyệt riêng. Đăng nhập `user01` ở chế độ Khách hàng và `user02` ở chế độ Freelancer, rồi kiểm tra cùng hợp đồng trong **Hợp đồng và thanh toán → Trọn gói**. Khách hàng có thể nạp ví mô phỏng rồi ký quỹ để freelancer kiểm tra trạng thái từ máy kia.
