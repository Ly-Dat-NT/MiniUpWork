-- Dữ liệu giả lập cho nhóm Rum. Chỉ nạp trên CSDL vừa dựng.
BEGIN;
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM miniupwork.app_user) OR EXISTS (SELECT 1 FROM miniupwork.job) THEN
        RAISE EXCEPTION 'Seed requires an empty database';
    END IF;
END; $$;

INSERT INTO miniupwork.app_user (user_id, username, email, password_hash, full_name) VALUES
    (1, 'user01', 'user01@miniupwork.example', 'pbkdf2_sha256$600000$9beb3e747436b40114fc8b3b3a795750$95c51709dfa3bb7b18f4703c0d8ab515942d3b26388e69039fab56938c052483', 'Nguyễn Minh An'),
    (2, 'user02', 'user02@miniupwork.example', 'pbkdf2_sha256$600000$e6472044fbc02f2c21d38e38174213a4$349e44075b17a258437865dbefad979362347961e04f588a59b1ce0ffaf85d24', 'Trần Gia Hân'),
    (3, 'user03', 'user03@miniupwork.example', 'pbkdf2_sha256$600000$9df1388085aa9c05eca76b8b11144658$e9292990b835f027999a7edd5288ce11d68ea574f16e66a888579befb296afc1', 'Lê Quốc Thịnh'),
    (4, 'user04', 'user04@miniupwork.example', 'pbkdf2_sha256$600000$1949d50251a135eb901828c1f9326526$d0e30259a83614c4e4ea3c527295e3e2969a4c78403fe3fbb330fb290e3f8eb5', 'Võ Mai Linh'),
    (5, 'user05', 'user05@miniupwork.example', 'pbkdf2_sha256$600000$2967b86dcc2a360dba05495375b6c540$e8d20466ec44c2cc7083624e06d96adaa43bc7bd44a4825ef8f4d4e5888658ca', 'Phạm Tuấn Kiệt'),
    (6, 'user06', 'user06@miniupwork.example', 'pbkdf2_sha256$600000$cd610703324830ce17f249842d73bffb$49ef0b5c988a0b433bf42358429c3de61a19603894138c6c0e0ffdeb92c7648f', 'Đặng Bảo Ngọc'),
    (7, 'user07', 'user07@miniupwork.example', 'pbkdf2_sha256$600000$42feb27b2d3944a0e644b3bfda2d0304$de0f1b6109d92999072c5cfa00f1c70220dcb2aa58093b4c8a3ad880629a0d9b', 'Đỗ Nhật Minh'),
    (8, 'user08', 'user08@miniupwork.example', 'pbkdf2_sha256$600000$a22672723e86e9c4eaee49d83ca44915$6eca279a9fad11d914501ed271295c352a3d88732298d7f8034551472ccedf92', 'Bùi Khánh Vy'),
    (9, 'user09', 'user09@miniupwork.example', 'pbkdf2_sha256$600000$fa0f7c394a3a82da7c33e094c6e19638$85d85490a9b30b94193ce532c931bfeac2b33724bc9bafdef9747d3add436cfe', 'Phan Thành Long'),
    (10, 'user10', 'user10@miniupwork.example', 'pbkdf2_sha256$600000$01b3063fcea2069b0b355bc6c9feca20$6abbc4643c7e2f07058dd6a8df17561f6ed7df31986dbd2e2c306569551cb69f', 'Huỳnh Hà Phương'),
    (11, 'user11', 'user11@miniupwork.example', 'pbkdf2_sha256$600000$e77b86b8c6da0f840fc820d1c4ef45bd$305590f624df1054da6cc51150992a6a33abfe397a4e07b8c879a2545114d543', 'Nguyễn Thanh Tâm'),
    (12, 'user12', 'user12@miniupwork.example', 'pbkdf2_sha256$600000$62b52887c4fff5535d114392df7d9969$80aeeafc1d645eff76071794acd98d029f0cd4eda2f37e226f9c5370424c4885', 'Lý Ánh Dương'),
    (13, 'user13', 'user13@miniupwork.example', 'pbkdf2_sha256$600000$e7fd50f2ecf33cacddb48ee28d3f2cd2$f7e3e509ded84413f67c6c3e05d467e9f858e1abf6c44aed294421fcab7f8897', 'Trương Hữu Phúc'),
    (14, 'user14', 'user14@miniupwork.example', 'pbkdf2_sha256$600000$422d13cf47f005c228332916dac2b6f0$a6c92a63d36d63267625aee425fab2906a21f9d4860f51c6ec19ec5cf976f1f2', 'Trần Ngọc Nhi'),
    (15, 'user15', 'user15@miniupwork.example', 'pbkdf2_sha256$600000$1f408cb3168a347f8af9ac1234cecab2$c7894100ffc2f285750d7e0eaf5b078fb2f7d0aa9bb36bf928774599d902871f', 'Vũ Quang Huy'),
    (16, 'user16', 'user16@miniupwork.example', 'pbkdf2_sha256$600000$fc3973109953d1aae081fcbe8e023f14$2ad3734ec802a47de95e9c0b127a96c2ec7883044e27c961ad9f97601084f21d', 'Ngô Thảo Uyên'),
    (17, 'user17', 'user17@miniupwork.example', 'pbkdf2_sha256$600000$d2602480f1b92977cd33a9ab74006c5a$ef3e359f6a2efbf7f604420e48d34d245265cb263ad673ad182db8b7f13e3077', 'Phạm Gia Bảo'),
    (18, 'user18', 'user18@miniupwork.example', 'pbkdf2_sha256$600000$f8bbc410ab6a074fdc7d4dd2fcd76c6c$01eb342401d6e99a7e10fa315642cc9fd03a5c45bb77c5dd33680d938769fa61', 'Đinh Thu Vân'),
    (19, 'user19', 'user19@miniupwork.example', 'pbkdf2_sha256$600000$02b74efe360490f0242283c6319f884c$b0ad5f85a480a18818ed9b50c0b100998e8d46f0ba96628b67ee0d6032faec63', 'Lê Bảo Khang'),
    (20, 'user20', 'user20@miniupwork.example', 'pbkdf2_sha256$600000$76e14388db7f0a83df1482783d73ec97$50b620d2230d0cb3bbc3b5f2d6d3a777610f1a16bfe83089474a6bce7ba4c8d8', 'Đỗ Hoàng Yến'),
    (21, 'user21', 'user21@miniupwork.example', 'pbkdf2_sha256$600000$73b09eb59c1c5b699399845c9e0f73d4$651db73feebed86e44c5b543e57a8242902b4ed7b5fd734158bdc7e904d08e98', 'Cao Tuệ Nghi'),
    (22, 'user22', 'user22@miniupwork.example', 'pbkdf2_sha256$600000$3426a05fa2fb57fcfc95baeab1793274$03d79194cb0f1edd8fa44630ec8bb8745a9c537b9eae3e87d7a2d79e9e1ec7fd', 'Lương Minh Đức'),
    (23, 'user23', 'user23@miniupwork.example', 'pbkdf2_sha256$600000$1cc16a9d1e8620f0062a274688160b59$946de8d1565f17e1340d5c496ecf80bc704138dd0fd360307163f77adf3ea6f1', 'Trần Thùy Dung'),
    (24, 'user24', 'user24@miniupwork.example', 'pbkdf2_sha256$600000$0d1c266182d2b3f31742abc1fdd56157$b6f7ed0381e5d7aae5e59876f84cceb90e2dcc9e693a1c353a30627b29eb83b4', 'Võ Thiên Vũ'),
    (25, 'user25', 'user25@miniupwork.example', 'pbkdf2_sha256$600000$448fa2116fefce9301ccf465cee567b0$1cd49056068d3c9a5848a20b1920d8d892d333bbddcd9a699c0c6d44e987f468', 'Hồ Thanh Lam'),
    (26, 'user26', 'user26@miniupwork.example', 'pbkdf2_sha256$600000$b2606192e4e6492d2a8778c74173569f$8c27339f7e38948f7c6694924e8e5acce6f401084faaa6bda244198170053f28', 'Nguyễn Trọng Nghĩa'),
    (27, 'user27', 'user27@miniupwork.example', 'pbkdf2_sha256$600000$164525e5887745defcac77154ba6cf29$f68c769cb3789c9dd910be34f55b17c14ab5c5692cdb55079553cff77615bc5a', 'Bùi Quỳnh Chi'),
    (28, 'user28', 'user28@miniupwork.example', 'pbkdf2_sha256$600000$e5acaaa8cd102c68be8a68c648177dbe$88d74384e84b914b744de796dee2fd868a2d06a6c0d762e3bc8ad9124fb84945', 'Phan Khải Nam'),
    (29, 'user29', 'user29@miniupwork.example', 'pbkdf2_sha256$600000$9224b4429dc2679ae21ed47261e8f265$0bae3b70b8b77edc3f8ece9e1810e6502e55964d13055a649a4a0d4dde48911e', 'Đặng Linh Đan'),
    (30, 'user30', 'user30@miniupwork.example', 'pbkdf2_sha256$600000$c54da33898b0d6fe3b7787f47c4e1ed3$9ad4b600ec85e4370886f9d10e321382aaaf8d1d42359768effd3913232a6a58', 'Lê Trúc Anh'),
    (31, 'user31', 'user31@miniupwork.example', 'pbkdf2_sha256$600000$92902dd8ccc179d5594eb1d9585b93cb$558c57c7528e6bcb0d6a6b773ac68921ee35d80504e92e7729a6bba45c4dc214', 'Vũ Hà My'),
    (32, 'user32', 'user32@miniupwork.example', 'pbkdf2_sha256$600000$66195896fd8c866a53f12b0fbc2969cd$6727aeb3b798bc3587f5407fc32c0db762f873f6156b558bd0e93aea3c1ab96a', 'Ngô Minh Quân'),
    (33, 'user33', 'user33@miniupwork.example', 'pbkdf2_sha256$600000$fc734b452b41b43583b412c2e76db83e$95f7cb0a3d68116919074a87e0c6e4b6904e847d556a9f31e9a31c1b93ccc89d', 'Trương Tú Oanh'),
    (34, 'user34', 'user34@miniupwork.example', 'pbkdf2_sha256$600000$fc7e6bb40f037771d52c51b8d4a90f5b$32c4e00fa59dc96b13ed7f5540776a42538103a26a877ebc7d62f513e0d61a7f', 'Hoàng Phúc Khoa'),
    (35, 'user35', 'user35@miniupwork.example', 'pbkdf2_sha256$600000$89ee233055e864318b84d6af0e26b09c$635b4426e4315262d3db0fe43f438d01b741293180fd781f6b5abd03cdec3376', 'Lý Kim Ngân'),
    (36, 'user36', 'user36@miniupwork.example', 'pbkdf2_sha256$600000$190261397e09337371d0b87666ca3370$e9b1812e9e1116a27d3d96a7285f5246f041a336d992159bcf18e75bceb50667', 'Nguyễn Tiến Khoa'),
    (37, 'user37', 'user37@miniupwork.example', 'pbkdf2_sha256$600000$e6f6b2cff080936e735b2f3352e892aa$3abb9556bbf16aa64be36517aab3aa1d3aa74ec88f4d17e2cff228777c1b2946', 'Trần Mỹ Duyên'),
    (38, 'user38', 'user38@miniupwork.example', 'pbkdf2_sha256$600000$bb54b5d5e76441cfc3476be917394f8d$3ff5184a3e2d71662506b2e1498a02c6fbb1f43f7a4030c77b3dbdc2dbe800ed', 'Lê Anh Kiệt'),
    (39, 'user39', 'user39@miniupwork.example', 'pbkdf2_sha256$600000$c7c94e17f3714c03e9995fb64f8f0b14$c9897f082eb51fbf44d123fa297882b7e41677e2c66ec65689f9dcd3b903472b', 'Hoàng Ngọc Thư'),
    (40, 'user40', 'user40@miniupwork.example', 'pbkdf2_sha256$600000$b3d4becb00180aed16c58a380e321dca$1ae3b9a0d3a2b40e815b1f79bff299ac33d7397dd22a773ceb84999e843db7a5', 'Đặng Hoài Nam'),
    (41, 'user41', 'user41@miniupwork.example', 'pbkdf2_sha256$600000$6e097a3c9fff8fda05a20c0a4abb49bc$196d1538a2b0e0935cf822904adc45be6ffbb826888fba852f3ce9c5b26905ff', 'Võ Minh Thảo'),
    (42, 'user42', 'user42@miniupwork.example', 'pbkdf2_sha256$600000$2bf8a11d88fa0f950ddbcf4dba3eecc1$d58c7f380f62951bc667736135878a98b28743099159da6740003747ee9e1c07', 'Phan Hải Yến'),
    (43, 'user43', 'user43@miniupwork.example', 'pbkdf2_sha256$600000$82c32e4d9aef2a52067de76d9bbd1cc2$c0060aab5749bec0b0a73f70f0ded824c48cee1764774696d85b2ef041f2ecd4', 'Bùi Thanh Sơn'),
    (44, 'user44', 'user44@miniupwork.example', 'pbkdf2_sha256$600000$e80c2c9137a08edf74c8d5e9e86c67a8$40b82a5ed80a30f4f8f2b928cd9c4ea7c58a4ac1c0e3cd1bb980cbf5df327e32', 'Ngô Lan Anh'),
    (45, 'user45', 'user45@miniupwork.example', 'pbkdf2_sha256$600000$32f4ff47f7d299cd32aa8c772fe669cd$a8bdeadda2ffc2e58ab541e76b59dd03225a69cb6dfb1c7306bcec023a04abcb', 'Đinh Quốc Bảo'),
    (46, 'user46', 'user46@miniupwork.example', 'pbkdf2_sha256$600000$302792a71b96319a7b0457db74472e06$e6a85a206fa1b43d389b3acdba0d4fff4d5787dd0f8cfdea149508ad7328aaff', 'Phạm Thu Hương'),
    (47, 'user47', 'user47@miniupwork.example', 'pbkdf2_sha256$600000$a52a7eaa3e1d83b5e68a0702edc5010b$5749236dd4a3c94d496326f70941f5fe304b59deb0fbaf3bfbce42d9ce8be32c', 'Vũ Gia Minh'),
    (48, 'user48', 'user48@miniupwork.example', 'pbkdf2_sha256$600000$fc7b37f17757761ea4266e26c669ca28$360955c15574c5a6aea4730d6961f1ee6efba2d6cc5f2a016aa55ac1e6ce3847', 'Đỗ Khánh Linh'),
    (49, 'user49', 'user49@miniupwork.example', 'pbkdf2_sha256$600000$12b524064d2a42e74eacca8c7dcd51eb$30c40e7eeee9c8907da19b0df1af7336ba564d066bf10589bf456c85a73c0de7', 'Hồ Quốc Đạt'),
    (50, 'user50', 'user50@miniupwork.example', 'pbkdf2_sha256$600000$ff79522543d4d8fb1247eec47c1949d3$1bfd2dc69321a990bf78b00568dae199eb19d47bab34c24fb01cf2d967e4d9e5', 'Nguyễn Ngọc Hạnh');


UPDATE miniupwork.app_user SET created_at = now() - make_interval(days => 240 + (user_id::int % 85));

INSERT INTO miniupwork.client (user_id, company_name, description) VALUES
    (36, 'Mộc Miên Commerce', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Mộc Miên Commerce.'),
    (37, 'Vườn Cam Studio', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Vườn Cam Studio.'),
    (38, 'Nếp Nhà Nội Thất', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Nếp Nhà Nội Thất.'),
    (39, 'Lưng Đồi Creative', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Lưng Đồi Creative.'),
    (40, 'Hương Sớm Coffee', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Hương Sớm Coffee.'),
    (41, 'Phòng khám Hạ Mai', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Phòng khám Hạ Mai.'),
    (42, 'Tủ Sách Đom Đóm', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Tủ Sách Đom Đóm.'),
    (43, 'Thềm Gạch Workshop', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Thềm Gạch Workshop.'),
    (44, 'Mùa Gió Logistics', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Mùa Gió Logistics.'),
    (45, 'Nét Việt Academy', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Nét Việt Academy.'),
    (46, 'Bờ Cát Events', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Bờ Cát Events.'),
    (47, 'Vòng Quay Bicycles', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Vòng Quay Bicycles.'),
    (48, 'Lan Can Media', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Lan Can Media.'),
    (49, 'Chồi Non Florist', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Chồi Non Florist.'),
    (50, 'Đường Sáng Apps', 'Nhóm vận hành và tuyển cộng tác viên theo dự án tại Đường Sáng Apps.');


INSERT INTO miniupwork.freelancer (user_id, headline, overview, default_hourly_rate, availability) VALUES
    (1, 'Lập trình viên web', 'Nhận dự án về phát triển web. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'AVAILABLE'),
    (2, 'Nhà thiết kế thương hiệu', 'Nhận dự án về thiết kế thương hiệu. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (3, 'Chuyên viên phân tích dữ liệu', 'Nhận dự án về phân tích dữ liệu. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (4, 'Biên tập viên nội dung', 'Nhận dự án về nội dung và biên tập. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'AVAILABLE'),
    (5, 'Biên tập viên video', 'Nhận dự án về video và hậu kỳ. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (6, 'Lập trình viên di động', 'Nhận dự án về ứng dụng di động. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (7, 'Chuyên viên tiếp thị số', 'Nhận dự án về tiếp thị số. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'AVAILABLE'),
    (8, 'Chuyên viên vận hành', 'Nhận dự án về vận hành và hỗ trợ. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (9, 'Biên dịch viên', 'Nhận dự án về dịch thuật và bản địa hóa. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (10, 'Kỹ sư kiểm thử', 'Nhận dự án về kiểm thử phần mềm. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'AVAILABLE'),
    (11, 'Lập trình viên web', 'Nhận dự án về phát triển web. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (12, 'Nhà thiết kế thương hiệu', 'Nhận dự án về thiết kế thương hiệu. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (13, 'Chuyên viên phân tích dữ liệu', 'Nhận dự án về phân tích dữ liệu. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'AVAILABLE'),
    (14, 'Biên tập viên nội dung', 'Nhận dự án về nội dung và biên tập. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (15, 'Biên tập viên video', 'Nhận dự án về video và hậu kỳ. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (16, 'Lập trình viên di động', 'Nhận dự án về ứng dụng di động. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'AVAILABLE'),
    (17, 'Chuyên viên tiếp thị số', 'Nhận dự án về tiếp thị số. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (18, 'Chuyên viên vận hành', 'Nhận dự án về vận hành và hỗ trợ. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (19, 'Biên dịch viên', 'Nhận dự án về dịch thuật và bản địa hóa. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'AVAILABLE'),
    (20, 'Kỹ sư kiểm thử', 'Nhận dự án về kiểm thử phần mềm. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (21, 'Lập trình viên web', 'Nhận dự án về phát triển web. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (22, 'Nhà thiết kế thương hiệu', 'Nhận dự án về thiết kế thương hiệu. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'AVAILABLE'),
    (23, 'Chuyên viên phân tích dữ liệu', 'Nhận dự án về phân tích dữ liệu. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (24, 'Biên tập viên nội dung', 'Nhận dự án về nội dung và biên tập. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (25, 'Biên tập viên video', 'Nhận dự án về video và hậu kỳ. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'UNAVAILABLE'),
    (26, 'Lập trình viên di động', 'Nhận dự án về ứng dụng di động. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (27, 'Chuyên viên tiếp thị số', 'Nhận dự án về tiếp thị số. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (28, 'Chuyên viên vận hành', 'Nhận dự án về vận hành và hỗ trợ. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'AVAILABLE'),
    (29, 'Biên dịch viên', 'Nhận dự án về dịch thuật và bản địa hóa. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (30, 'Kỹ sư kiểm thử', 'Nhận dự án về kiểm thử phần mềm. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (31, 'Lập trình viên web', 'Nhận dự án về phát triển web. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'UNAVAILABLE'),
    (32, 'Nhà thiết kế thương hiệu', 'Nhận dự án về thiết kế thương hiệu. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE'),
    (33, 'Chuyên viên phân tích dữ liệu', 'Nhận dự án về phân tích dữ liệu. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 17, 'AVAILABLE'),
    (34, 'Biên tập viên nội dung', 'Nhận dự án về nội dung và biên tập. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 24, 'UNAVAILABLE'),
    (35, 'Biên tập viên video', 'Nhận dự án về video và hậu kỳ. Có kinh nghiệm bàn giao theo mốc và trao đổi tiến độ hằng tuần.', 31, 'AVAILABLE');


INSERT INTO miniupwork.category (category_id, category_name) VALUES
    (1, 'Phát triển web'),
    (2, 'Thiết kế thương hiệu'),
    (3, 'Phân tích dữ liệu'),
    (4, 'Nội dung và biên tập'),
    (5, 'Video và hậu kỳ'),
    (6, 'Ứng dụng di động'),
    (7, 'Tiếp thị số'),
    (8, 'Vận hành và hỗ trợ'),
    (9, 'Dịch thuật và bản địa hóa'),
    (10, 'Kiểm thử phần mềm');


INSERT INTO miniupwork.skill (skill_id, skill_name) VALUES
    (1, 'Python'),
    (2, 'FastAPI'),
    (3, 'PostgreSQL'),
    (4, 'Figma'),
    (5, 'Illustrator'),
    (6, 'Thiết kế thương hiệu'),
    (7, 'SQL'),
    (8, 'Power BI'),
    (9, 'Excel'),
    (10, 'Biên tập'),
    (11, 'SEO'),
    (12, 'Viết tiếng Việt'),
    (13, 'DaVinci Resolve'),
    (14, 'Premiere Pro'),
    (15, 'Dựng video'),
    (16, 'Flutter'),
    (17, 'Dart'),
    (18, 'Firebase'),
    (19, 'Google Ads'),
    (20, 'GA4'),
    (21, 'Báo cáo chiến dịch'),
    (22, 'Google Sheets'),
    (23, 'Chăm sóc khách hàng'),
    (24, 'Quản lý đơn hàng'),
    (25, 'Tiếng Anh'),
    (26, 'Dịch thuật'),
    (27, 'Quản lý thuật ngữ'),
    (28, 'Playwright'),
    (29, 'Postman'),
    (30, 'Kiểm thử phần mềm');


INSERT INTO miniupwork.freelancer_skill (freelancer_id, skill_id, proficiency_level) VALUES
    (1, 1, 5),
    (1, 2, 3),
    (1, 3, 4),
    (2, 4, 3),
    (2, 5, 4),
    (2, 6, 5),
    (3, 7, 4),
    (3, 8, 5),
    (3, 9, 3),
    (4, 10, 5),
    (4, 11, 3),
    (4, 12, 4),
    (5, 13, 3),
    (5, 14, 4),
    (5, 15, 5),
    (6, 16, 4),
    (6, 17, 5),
    (6, 18, 3),
    (7, 19, 5),
    (7, 20, 3),
    (7, 21, 4),
    (8, 22, 3),
    (8, 23, 4),
    (8, 24, 5),
    (9, 25, 4),
    (9, 26, 5),
    (9, 27, 3),
    (10, 28, 5),
    (10, 29, 3),
    (10, 30, 4),
    (11, 1, 3),
    (11, 2, 4),
    (11, 3, 5),
    (12, 4, 4),
    (12, 5, 5),
    (12, 6, 3),
    (13, 7, 5),
    (13, 8, 3),
    (13, 9, 4),
    (14, 10, 3),
    (14, 11, 4),
    (14, 12, 5),
    (15, 13, 4),
    (15, 14, 5),
    (15, 15, 3),
    (16, 16, 5),
    (16, 17, 3),
    (16, 18, 4),
    (17, 19, 3),
    (17, 20, 4),
    (17, 21, 5),
    (18, 22, 4),
    (18, 23, 5),
    (18, 24, 3),
    (19, 25, 5),
    (19, 26, 3),
    (19, 27, 4),
    (20, 28, 3),
    (20, 29, 4),
    (20, 30, 5),
    (21, 1, 4),
    (21, 2, 5),
    (21, 3, 3),
    (22, 4, 5),
    (22, 5, 3),
    (22, 6, 4),
    (23, 7, 3),
    (23, 8, 4),
    (23, 9, 5),
    (24, 10, 4),
    (24, 11, 5),
    (24, 12, 3),
    (25, 13, 5),
    (25, 14, 3),
    (25, 15, 4),
    (26, 16, 3),
    (26, 17, 4),
    (26, 18, 5),
    (27, 19, 4),
    (27, 20, 5),
    (27, 21, 3),
    (28, 22, 5),
    (28, 23, 3),
    (28, 24, 4),
    (29, 25, 3),
    (29, 26, 4),
    (29, 27, 5),
    (30, 28, 4),
    (30, 29, 5),
    (30, 30, 3),
    (31, 1, 5),
    (31, 2, 3),
    (31, 3, 4),
    (32, 4, 3),
    (32, 5, 4),
    (32, 6, 5),
    (33, 7, 4),
    (33, 8, 5),
    (33, 9, 3),
    (34, 10, 5),
    (34, 11, 3),
    (34, 12, 4),
    (35, 13, 3),
    (35, 14, 4),
    (35, 15, 5);


INSERT INTO miniupwork.job (job_id, client_id, category_id, title, description, job_type) VALUES
    (1, 41, 1, 'Xây trang đặt lịch cho phòng khám nha khoa', 'Cần form đặt lịch, xác nhận email và trang quản lý lịch hẹn cho lễ tân. Thiết kế đã có sẵn.', 'FIXED_PRICE'),
    (2, 36, 1, 'Kết nối cổng tồn kho với trang bán đồ gốm', 'Đồng bộ số lượng theo SKU mỗi 15 phút, ghi lại lần cập nhật lỗi và bàn giao hướng dẫn vận hành.', 'FIXED_PRICE'),
    (3, 36, 1, 'Bảo trì API giao hàng cho cửa hàng thời trang', 'Rà soát lỗi timeout, bổ sung nhật ký lỗi và kiểm thử hai tuyến giao hàng đang hoạt động.', 'HOURLY'),
    (4, 40, 1, 'Tối ưu trang đặt bàn quán cà phê', 'Giảm thời gian tải ảnh thực đơn và sửa trạng thái còn bàn khi người dùng đổi ngày.', 'HOURLY'),
    (5, 46, 1, 'Dựng cổng đăng ký hội thảo nội bộ', 'Trang đăng ký tối đa 200 người, xuất danh sách CSV và gửi thư xác nhận tự động.', 'FIXED_PRICE'),
    (6, 43, 2, 'Thiết kế bộ nhận diện cho tiệm bánh sourdough', 'Cần logo chữ, bảng màu, nhãn niêm phong và hướng dẫn dùng logo trên bao bì.', 'HOURLY'),
    (7, 38, 2, 'Làm catalog bộ sưu tập nội thất mùa thu', 'Dàn 12 trang theo bộ ảnh hiện có, xuất PDF in và bản dung lượng nhẹ gửi khách.', 'FIXED_PRICE'),
    (8, 45, 2, 'Chuẩn hóa bộ icon cho ứng dụng học ngoại ngữ', 'Vẽ 24 biểu tượng đồng nhất, bàn giao file gốc có lưới và biến thể sáng tối.', 'HOURLY'),
    (9, 39, 2, 'Thiết kế nhãn hộp trà hoa cúc', 'Thử hai phối màu, chừa vị trí thông tin bắt buộc và bàn giao bản in theo khuôn.', 'FIXED_PRICE'),
    (10, 37, 2, 'Dàn bộ mẫu bài đăng cho studio yoga', 'Thiết kế 8 mẫu có thể sửa nội dung và định nghĩa rõ khoảng cách, phông chữ.', 'HOURLY'),
    (11, 40, 3, 'Làm bảng theo dõi doanh thu cho chuỗi cà phê', 'Gộp file bán hàng của 4 chi nhánh, đối chiếu mã sản phẩm và trình bày doanh thu theo tuần.', 'FIXED_PRICE'),
    (12, 47, 3, 'Chuẩn hóa báo cáo tồn kho cho cửa hàng xe đạp', 'Loại dòng trùng, đối chiếu nhập xuất theo SKU và làm mẫu báo cáo có thể cập nhật mỗi tháng.', 'FIXED_PRICE'),
    (13, 45, 3, 'Phân tích lý do khách hủy lịch học', 'Đọc dữ liệu đã ẩn danh, phân nhóm lý do và trao đổi kết quả với người phụ trách lớp.', 'HOURLY'),
    (14, 44, 3, 'Rà soát sai lệch đơn giao trong tuần', 'Tạo truy vấn đối chiếu thời gian giao thực tế với thời gian báo khách và phân loại trễ.', 'HOURLY'),
    (15, 38, 3, 'Trực quan hóa chi phí mở chi nhánh mới', 'Tách chi phí theo hạng mục, so với dự toán và trình bày biểu đồ cho buổi họp nội bộ.', 'FIXED_PRICE'),
    (16, 49, 4, 'Viết sáu bài hướng dẫn chăm sóc cây trong nhà', 'Mỗi bài 700–900 từ, cần dàn ý rõ, hướng dẫn theo mùa và nguồn tham khảo có thể tra cứu.', 'HOURLY'),
    (17, 44, 4, 'Biên tập bộ câu hỏi thường gặp cho dịch vụ giao hàng', 'Rút gọn 30 câu trả lời, đồng bộ cách xưng hô và đánh dấu phần cần xác minh với nhóm vận hành.', 'FIXED_PRICE'),
    (18, 37, 4, 'Soát nội dung bản tin tháng cho không gian làm việc chung', 'Biên tập bản thảo song ngữ đã có, kiểm tra đường dẫn và rút gọn từng mục để đọc trên điện thoại.', 'HOURLY'),
    (19, 36, 4, 'Viết mô tả cho bộ sưu tập áo linen', 'Viết mô tả 18 mặt hàng dựa trên ghi chú chất liệu và số đo do nhóm sản phẩm cung cấp.', 'FIXED_PRICE'),
    (20, 42, 4, 'Chuẩn hóa giọng văn cho trang hỗ trợ thanh toán', 'Soát 15 đoạn thông báo trạng thái và thống nhất thuật ngữ đang dùng trên ứng dụng.', 'HOURLY'),
    (21, 43, 5, 'Dựng video giới thiệu xưởng gốm thủ công', 'Từ 70 phút tư liệu, dựng một video 90 giây và ba phiên bản dọc ngắn cho mạng xã hội.', 'FIXED_PRICE'),
    (22, 48, 5, 'Dựng phỏng vấn khách hàng cho triển lãm ảnh', 'Cắt theo dàn ý, làm sạch âm thanh, cân màu và bàn giao phụ đề rời.', 'FIXED_PRICE'),
    (23, 40, 5, 'Chỉnh màu bộ video hướng dẫn pha cà phê', 'Đồng bộ màu của hai máy quay, giữ màu da tự nhiên và gửi một đoạn mẫu trước khi xử lý hàng loạt.', 'HOURLY'),
    (24, 44, 5, 'Tách clip ngắn từ webinar quản lý kho', 'Chọn 5 đoạn có giá trị độc lập, thêm phụ đề và khung mở đầu theo nhận diện có sẵn.', 'HOURLY'),
    (25, 39, 5, 'Chỉnh âm thanh cho podcast thiết kế bền vững', 'Giảm tạp âm, cân độ lớn giữa khách mời và người dẫn, xuất 3 tập dạng WAV và MP3.', 'FIXED_PRICE'),
    (26, 50, 6, 'Xây màn hình theo dõi buổi tập bằng Flutter', 'Tích hợp API lịch tập, lọc theo tuần và hiển thị trạng thái mất kết nối có nút thử lại.', 'FIXED_PRICE'),
    (27, 36, 6, 'Làm luồng thêm địa chỉ giao hàng trên Android', 'Hỗ trợ sửa địa chỉ, kiểm tra phường xã và lưu trạng thái điền dở khi quay lại màn hình.', 'FIXED_PRICE'),
    (28, 50, 6, 'Sửa lỗi đồng bộ giỏ hàng đa thiết bị', 'Tái hiện lỗi trên hai thiết bị Android, kiểm tra thời điểm merge và viết kiểm thử hồi quy.', 'HOURLY'),
    (29, 41, 6, 'Cập nhật thông báo đặt lịch trên iOS', 'Xử lý quyền thông báo bị từ chối và kiểm tra mở đúng màn hình khi bấm thông báo.', 'HOURLY'),
    (30, 40, 6, 'Tạo bản dùng thử ứng dụng tra cứu thực đơn', 'Tập trung vào màn hình thực đơn, tìm món theo tên và thống kê lượt dùng nội bộ.', 'FIXED_PRICE'),
    (31, 45, 7, 'Lập kế hoạch quảng cáo cho khóa vẽ cuối tuần', 'Đề xuất nhóm từ khóa, mẫu quảng cáo và cách đo đăng ký cho chiến dịch kéo dài bốn tuần.', 'HOURLY'),
    (32, 39, 7, 'Kiểm tra sự kiện mua hàng trên trang bán trà', 'Đối chiếu GA4 với hệ thống đơn hàng, xác minh trùng sự kiện và tổng hợp lỗi theo thiết bị.', 'FIXED_PRICE'),
    (33, 45, 7, 'Vận hành quảng cáo tìm kiếm cho lớp tiếng Nhật', 'Rà cụm từ tìm kiếm, điều chỉnh ngân sách theo lịch học và báo cáo mỗi thứ Hai.', 'HOURLY'),
    (34, 46, 7, 'Chuẩn hóa UTM cho nhóm truyền thông sự kiện', 'Thiết kế quy ước gắn thẻ, sửa mẫu theo dõi và hướng dẫn nhóm vận hành.', 'FIXED_PRICE'),
    (35, 47, 7, 'Đo chuyển đổi cho trang đặt lịch thử xe', 'Thêm theo dõi bước chọn lịch, hẹn thành công và gọi điện. Cần bảng kiểm thử trước khi chạy.', 'HOURLY'),
    (36, 44, 8, 'Chuẩn hóa danh sách đơn lỗi cho cửa hàng giày', 'Làm bảng phân loại lỗi giao hàng, có mẫu liên hệ đối tác và ghi rõ thời hạn phản hồi.', 'FIXED_PRICE'),
    (37, 36, 8, 'Tạo quy trình tiếp nhận yêu cầu bảo hành', 'Làm mẫu tiếp nhận, bảng theo dõi tiến độ và hướng dẫn bàn giao giữa ca sáng và ca tối.', 'FIXED_PRICE'),
    (38, 44, 8, 'Hỗ trợ đối soát đơn đổi trả trong 2 tuần', 'Đối chiếu danh sách từ kho và chăm sóc khách hàng, cập nhật trạng thái theo từng ca.', 'HOURLY'),
    (39, 41, 8, 'Sắp lịch hẹn cho đợt khám răng định kỳ', 'Gọi xác nhận theo kịch bản có sẵn và báo lễ tân các khung giờ cần điều chỉnh.', 'HOURLY'),
    (40, 49, 8, 'Xây mẫu theo dõi vật tư cho tiệm hoa', 'Tạo danh mục vật tư, định mức tiết kiệm và lưu lịch sử nhập từng tuần.', 'FIXED_PRICE'),
    (41, 38, 9, 'Dịch hướng dẫn lắp đặt đèn trang trí', 'Dịch 4.500 từ Anh–Việt. Bản dịch cần khớp nhãn các linh kiện trong 12 hình minh họa.', 'FIXED_PRICE'),
    (42, 47, 9, 'Dịch danh mục tour xe đạp sang tiếng Anh', 'Dịch 11 tuyến, giữ nguyên tên riêng và chuẩn hóa đơn vị khoảng cách, độ cao.', 'FIXED_PRICE'),
    (43, 50, 9, 'Soát bản dịch giao diện phần mềm đặt lịch', 'Rà 420 chuỗi ngắn từ bảng thuật ngữ có sẵn và ghi trường hợp cần ngữ cảnh màn hình.', 'HOURLY'),
    (44, 43, 9, 'Dịch phụ đề video hướng dẫn làm gốm', 'Dịch bốn đoạn, giữ đúng timecode và đối chiếu thuật ngữ với bộ từ đã chuẩn hóa.', 'FIXED_PRICE'),
    (45, 38, 9, 'Hiệu đính hồ sơ giới thiệu xưởng nội thất', 'Hiệu đính bản tiếng Anh 10 trang và thống nhất tên dòng sản phẩm trên toàn bộ hồ sơ.', 'HOURLY'),
    (46, 46, 10, 'Kiểm thử luồng đặt vé triển lãm cuối tuần', 'Kiểm tra mua một vé, nhiều vé và hủy đơn. Gửi lỗi kèm bước tái hiện và ảnh màn hình.', 'FIXED_PRICE'),
    (47, 41, 10, 'Viết bộ kiểm thử API cho cổng đặt lịch', 'Tạo kịch bản cho đặt, đổi và hủy lịch; bổ sung dữ liệu biên và hướng dẫn chạy tự động.', 'FIXED_PRICE'),
    (48, 43, 10, 'Kiểm thử đa trình duyệt trang bán bánh', 'Theo dõi luồng giỏ hàng trên Chrome, Edge và kích thước điện thoại phổ biến.', 'HOURLY'),
    (49, 50, 10, 'Rà hồi quy hệ thống theo dõi hợp đồng', 'Cập nhật danh sách kiểm thử khi đổi trạng thái, kiểm tra quyền xem và dữ liệu lịch sử.', 'HOURLY'),
    (50, 36, 10, 'Tạo dữ liệu kiểm thử cho tính năng xuất hóa đơn', 'Chuẩn bị đơn nhiều thuế suất, lỗi số hóa đơn trùng, và đối chiếu ba định dạng xuất.', 'FIXED_PRICE');


UPDATE miniupwork.job SET posted_at = now() - make_interval(days => CASE
           WHEN (job_id - 1) % 5 = 0 THEN (job_id::int / 5) % 8 + 1
           ELSE 65 + (job_id::int % 35) END);

INSERT INTO miniupwork.fixed_price_job (job_id, budget_amount) VALUES
    (1, 780),
    (2, 560),
    (5, 420),
    (7, 410),
    (9, 290),
    (11, 620),
    (12, 360),
    (15, 460),
    (17, 250),
    (19, 230),
    (21, 540),
    (22, 310),
    (25, 240),
    (26, 870),
    (27, 440),
    (30, 740),
    (32, 350),
    (34, 240),
    (36, 220),
    (37, 260),
    (40, 230),
    (41, 380),
    (42, 310),
    (44, 280),
    (46, 460),
    (47, 420),
    (50, 350);


INSERT INTO miniupwork.hourly_job (job_id, rate_min, rate_max) VALUES
    (3, 22, 36),
    (4, 20, 32),
    (6, 19, 30),
    (8, 18, 28),
    (10, 16, 25),
    (13, 22, 38),
    (14, 19, 34),
    (16, 16, 24),
    (18, 14, 23),
    (20, 16, 25),
    (23, 23, 37),
    (24, 18, 30),
    (28, 28, 45),
    (29, 25, 40),
    (31, 20, 32),
    (33, 20, 34),
    (35, 25, 38),
    (38, 13, 22),
    (39, 12, 21),
    (43, 19, 32),
    (45, 20, 33),
    (48, 22, 36),
    (49, 24, 39);


INSERT INTO miniupwork.job_skill (job_id, skill_id, required_level) VALUES
    (1, 1, 2),
    (1, 2, 3),
    (2, 1, 3),
    (2, 2, 2),
    (3, 1, 2),
    (3, 2, 3),
    (4, 1, 3),
    (4, 2, 2),
    (5, 1, 2),
    (5, 2, 3),
    (6, 4, 3),
    (6, 5, 2),
    (7, 4, 2),
    (7, 5, 3),
    (8, 4, 3),
    (8, 5, 2),
    (9, 4, 2),
    (9, 5, 3),
    (10, 4, 3),
    (10, 5, 2),
    (11, 7, 2),
    (11, 8, 3),
    (12, 7, 3),
    (12, 8, 2),
    (13, 7, 2),
    (13, 8, 3),
    (14, 7, 3),
    (14, 8, 2),
    (15, 7, 2),
    (15, 8, 3),
    (16, 10, 3),
    (16, 11, 2),
    (17, 10, 2),
    (17, 11, 3),
    (18, 10, 3),
    (18, 11, 2),
    (19, 10, 2),
    (19, 11, 3),
    (20, 10, 3),
    (20, 11, 2),
    (21, 13, 2),
    (21, 14, 3),
    (22, 13, 3),
    (22, 14, 2),
    (23, 13, 2),
    (23, 14, 3),
    (24, 13, 3),
    (24, 14, 2),
    (25, 13, 2),
    (25, 14, 3),
    (26, 16, 3),
    (26, 17, 2),
    (27, 16, 2),
    (27, 17, 3),
    (28, 16, 3),
    (28, 17, 2),
    (29, 16, 2),
    (29, 17, 3),
    (30, 16, 3),
    (30, 17, 2),
    (31, 19, 2),
    (31, 20, 3),
    (32, 19, 3),
    (32, 20, 2),
    (33, 19, 2),
    (33, 20, 3),
    (34, 19, 3),
    (34, 20, 2),
    (35, 19, 2),
    (35, 20, 3),
    (36, 22, 3),
    (36, 23, 2),
    (37, 22, 2),
    (37, 23, 3),
    (38, 22, 3),
    (38, 23, 2),
    (39, 22, 2),
    (39, 23, 3),
    (40, 22, 3),
    (40, 23, 2),
    (41, 25, 2),
    (41, 26, 3),
    (42, 25, 3),
    (42, 26, 2),
    (43, 25, 2),
    (43, 26, 3),
    (44, 25, 3),
    (44, 26, 2),
    (45, 25, 2),
    (45, 26, 3),
    (46, 28, 3),
    (46, 29, 2),
    (47, 28, 2),
    (47, 29, 3),
    (48, 28, 3),
    (48, 29, 2),
    (49, 28, 2),
    (49, 29, 3),
    (50, 28, 3),
    (50, 29, 2);


UPDATE miniupwork.job SET status = 'OPEN' WHERE status = 'DRAFT';

INSERT INTO miniupwork.proposal (proposal_id, job_id, freelancer_id, cover_letter, offered_amount, submitted_at)
SELECT v.*, j.posted_at + make_interval(hours => 4 + v.proposal_id::int % 21)
FROM (VALUES
    (1, 1, 11, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “xây trang đặt lịch cho phòng khám nha khoa”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 713),
    (2, 1, 21, 'Tôi làm về phát triển web. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “xây trang đặt lịch cho phòng khám nha khoa”.', 733),
    (3, 1, 31, 'Chào anh chị, tôi từng bàn giao các đầu việc phát triển web theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 752),
    (4, 2, 1, 'Chào anh chị, tôi từng bàn giao các đầu việc phát triển web theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 512),
    (5, 2, 11, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “kết nối cổng tồn kho với trang bán đồ gốm”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 526),
    (6, 3, 1, 'Chào anh chị, tôi từng bàn giao các đầu việc phát triển web theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 24),
    (7, 3, 11, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “bảo trì api giao hàng cho cửa hàng thời trang”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 26),
    (8, 3, 21, 'Tôi làm về phát triển web. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “bảo trì api giao hàng cho cửa hàng thời trang”.', 28),
    (9, 4, 1, 'Chào anh chị, tôi từng bàn giao các đầu việc phát triển web theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 22),
    (10, 4, 11, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “tối ưu trang đặt bàn quán cà phê”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 24),
    (11, 6, 2, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “thiết kế bộ nhận diện cho tiệm bánh sourdough”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 21),
    (12, 6, 12, 'Tôi làm về thiết kế thương hiệu. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “thiết kế bộ nhận diện cho tiệm bánh sourdough”.', 23),
    (13, 7, 2, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “làm catalog bộ sưu tập nội thất mùa thu”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 375),
    (14, 7, 12, 'Tôi làm về thiết kế thương hiệu. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “làm catalog bộ sưu tập nội thất mùa thu”.', 385),
    (15, 7, 22, 'Chào anh chị, tôi từng bàn giao các đầu việc thiết kế thương hiệu theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 395),
    (16, 8, 2, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “chuẩn hóa bộ icon cho ứng dụng học ngoại ngữ”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 20),
    (17, 8, 12, 'Tôi làm về thiết kế thương hiệu. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “chuẩn hóa bộ icon cho ứng dụng học ngoại ngữ”.', 22),
    (18, 9, 2, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “thiết kế nhãn hộp trà hoa cúc”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 265),
    (19, 9, 12, 'Tôi làm về thiết kế thương hiệu. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “thiết kế nhãn hộp trà hoa cúc”.', 272),
    (20, 9, 22, 'Chào anh chị, tôi từng bàn giao các đầu việc thiết kế thương hiệu theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 279),
    (21, 11, 3, 'Tôi làm về phân tích dữ liệu. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “làm bảng theo dõi doanh thu cho chuỗi cà phê”.', 567),
    (22, 11, 13, 'Chào anh chị, tôi từng bàn giao các đầu việc phân tích dữ liệu theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 582),
    (23, 11, 23, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “làm bảng theo dõi doanh thu cho chuỗi cà phê”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 598),
    (24, 12, 3, 'Tôi làm về phân tích dữ liệu. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “chuẩn hóa báo cáo tồn kho cho cửa hàng xe đạp”.', 329),
    (25, 12, 13, 'Chào anh chị, tôi từng bàn giao các đầu việc phân tích dữ liệu theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 338),
    (26, 13, 3, 'Tôi làm về phân tích dữ liệu. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “phân tích lý do khách hủy lịch học”.', 24),
    (27, 13, 13, 'Chào anh chị, tôi từng bàn giao các đầu việc phân tích dữ liệu theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 26),
    (28, 13, 23, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “phân tích lý do khách hủy lịch học”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 28),
    (29, 14, 3, 'Tôi làm về phân tích dữ liệu. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “rà soát sai lệch đơn giao trong tuần”.', 21),
    (30, 14, 13, 'Chào anh chị, tôi từng bàn giao các đầu việc phân tích dữ liệu theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 23),
    (31, 16, 4, 'Chào anh chị, tôi từng bàn giao các đầu việc nội dung và biên tập theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 18),
    (32, 16, 14, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “viết sáu bài hướng dẫn chăm sóc cây trong nhà”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 20),
    (33, 17, 4, 'Chào anh chị, tôi từng bàn giao các đầu việc nội dung và biên tập theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 228),
    (34, 17, 14, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “biên tập bộ câu hỏi thường gặp cho dịch vụ giao hàng”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 235),
    (35, 17, 24, 'Tôi làm về nội dung và biên tập. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “biên tập bộ câu hỏi thường gặp cho dịch vụ giao hàng”.', 241),
    (36, 18, 4, 'Chào anh chị, tôi từng bàn giao các đầu việc nội dung và biên tập theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 16),
    (37, 18, 14, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “soát nội dung bản tin tháng cho không gian làm việc chung”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 18),
    (38, 19, 4, 'Chào anh chị, tôi từng bàn giao các đầu việc nội dung và biên tập theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 210),
    (39, 19, 14, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “viết mô tả cho bộ sưu tập áo linen”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 216),
    (40, 19, 24, 'Tôi làm về nội dung và biên tập. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “viết mô tả cho bộ sưu tập áo linen”.', 221),
    (41, 21, 5, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “dựng video giới thiệu xưởng gốm thủ công”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 494),
    (42, 21, 15, 'Tôi làm về video và hậu kỳ. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “dựng video giới thiệu xưởng gốm thủ công”.', 507),
    (43, 21, 25, 'Chào anh chị, tôi từng bàn giao các đầu việc video và hậu kỳ theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 521),
    (44, 22, 5, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “dựng phỏng vấn khách hàng cho triển lãm ảnh”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 283),
    (45, 22, 15, 'Tôi làm về video và hậu kỳ. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “dựng phỏng vấn khách hàng cho triển lãm ảnh”.', 291),
    (46, 23, 5, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “chỉnh màu bộ video hướng dẫn pha cà phê”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 25),
    (47, 23, 15, 'Tôi làm về video và hậu kỳ. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “chỉnh màu bộ video hướng dẫn pha cà phê”.', 27),
    (48, 23, 25, 'Chào anh chị, tôi từng bàn giao các đầu việc video và hậu kỳ theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 29),
    (49, 24, 5, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “tách clip ngắn từ webinar quản lý kho”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 20),
    (50, 24, 15, 'Tôi làm về video và hậu kỳ. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “tách clip ngắn từ webinar quản lý kho”.', 22),
    (51, 26, 6, 'Tôi làm về ứng dụng di động. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “xây màn hình theo dõi buổi tập bằng flutter”.', 796),
    (52, 26, 16, 'Chào anh chị, tôi từng bàn giao các đầu việc ứng dụng di động theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 817),
    (53, 27, 6, 'Tôi làm về ứng dụng di động. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “làm luồng thêm địa chỉ giao hàng trên android”.', 402),
    (54, 27, 16, 'Chào anh chị, tôi từng bàn giao các đầu việc ứng dụng di động theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 413),
    (55, 27, 26, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “làm luồng thêm địa chỉ giao hàng trên android”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 424),
    (56, 28, 6, 'Tôi làm về ứng dụng di động. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “sửa lỗi đồng bộ giỏ hàng đa thiết bị”.', 30),
    (57, 28, 16, 'Chào anh chị, tôi từng bàn giao các đầu việc ứng dụng di động theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 32),
    (58, 29, 6, 'Tôi làm về ứng dụng di động. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “cập nhật thông báo đặt lịch trên ios”.', 27),
    (59, 29, 16, 'Chào anh chị, tôi từng bàn giao các đầu việc ứng dụng di động theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 29),
    (60, 29, 26, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “cập nhật thông báo đặt lịch trên ios”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 31),
    (61, 30, 6, 'Tôi làm về ứng dụng di động. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “tạo bản dùng thử ứng dụng tra cứu thực đơn”.', 677),
    (62, 30, 16, 'Chào anh chị, tôi từng bàn giao các đầu việc ứng dụng di động theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 695),
    (63, 31, 7, 'Chào anh chị, tôi từng bàn giao các đầu việc tiếp thị số theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 22),
    (64, 31, 17, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “lập kế hoạch quảng cáo cho khóa vẽ cuối tuần”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 24),
    (65, 31, 27, 'Tôi làm về tiếp thị số. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “lập kế hoạch quảng cáo cho khóa vẽ cuối tuần”.', 26),
    (66, 32, 7, 'Chào anh chị, tôi từng bàn giao các đầu việc tiếp thị số theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 320),
    (67, 32, 17, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “kiểm tra sự kiện mua hàng trên trang bán trà”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 329),
    (68, 33, 7, 'Chào anh chị, tôi từng bàn giao các đầu việc tiếp thị số theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 22),
    (69, 33, 17, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “vận hành quảng cáo tìm kiếm cho lớp tiếng nhật”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 24),
    (70, 33, 27, 'Tôi làm về tiếp thị số. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “vận hành quảng cáo tìm kiếm cho lớp tiếng nhật”.', 26),
    (71, 34, 7, 'Chào anh chị, tôi từng bàn giao các đầu việc tiếp thị số theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 219),
    (72, 34, 17, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “chuẩn hóa utm cho nhóm truyền thông sự kiện”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 225),
    (73, 35, 7, 'Chào anh chị, tôi từng bàn giao các đầu việc tiếp thị số theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 27),
    (74, 35, 17, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “đo chuyển đổi cho trang đặt lịch thử xe”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 29),
    (75, 35, 27, 'Tôi làm về tiếp thị số. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “đo chuyển đổi cho trang đặt lịch thử xe”.', 31),
    (76, 36, 8, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “chuẩn hóa danh sách đơn lỗi cho cửa hàng giày”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 201),
    (77, 36, 18, 'Tôi làm về vận hành và hỗ trợ. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “chuẩn hóa danh sách đơn lỗi cho cửa hàng giày”.', 206),
    (78, 37, 8, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “tạo quy trình tiếp nhận yêu cầu bảo hành”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 237),
    (79, 37, 18, 'Tôi làm về vận hành và hỗ trợ. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “tạo quy trình tiếp nhận yêu cầu bảo hành”.', 244),
    (80, 37, 28, 'Chào anh chị, tôi từng bàn giao các đầu việc vận hành và hỗ trợ theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 250),
    (81, 38, 8, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “hỗ trợ đối soát đơn đổi trả trong 2 tuần”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 15),
    (82, 38, 18, 'Tôi làm về vận hành và hỗ trợ. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “hỗ trợ đối soát đơn đổi trả trong 2 tuần”.', 17),
    (83, 39, 8, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “sắp lịch hẹn cho đợt khám răng định kỳ”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 14),
    (84, 39, 18, 'Tôi làm về vận hành và hỗ trợ. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “sắp lịch hẹn cho đợt khám răng định kỳ”.', 16),
    (85, 39, 28, 'Chào anh chị, tôi từng bàn giao các đầu việc vận hành và hỗ trợ theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 18),
    (86, 40, 8, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “xây mẫu theo dõi vật tư cho tiệm hoa”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 210),
    (87, 40, 18, 'Tôi làm về vận hành và hỗ trợ. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “xây mẫu theo dõi vật tư cho tiệm hoa”.', 216),
    (88, 41, 9, 'Tôi làm về dịch thuật và bản địa hóa. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “dịch hướng dẫn lắp đặt đèn trang trí”.', 347),
    (89, 41, 19, 'Chào anh chị, tôi từng bàn giao các đầu việc dịch thuật và bản địa hóa theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 357),
    (90, 41, 29, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “dịch hướng dẫn lắp đặt đèn trang trí”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 366),
    (91, 42, 9, 'Tôi làm về dịch thuật và bản địa hóa. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “dịch danh mục tour xe đạp sang tiếng anh”.', 283),
    (92, 42, 19, 'Chào anh chị, tôi từng bàn giao các đầu việc dịch thuật và bản địa hóa theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 291),
    (93, 43, 9, 'Tôi làm về dịch thuật và bản địa hóa. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “soát bản dịch giao diện phần mềm đặt lịch”.', 21),
    (94, 43, 19, 'Chào anh chị, tôi từng bàn giao các đầu việc dịch thuật và bản địa hóa theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 23),
    (95, 43, 29, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “soát bản dịch giao diện phần mềm đặt lịch”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 25),
    (96, 44, 9, 'Tôi làm về dịch thuật và bản địa hóa. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “dịch phụ đề video hướng dẫn làm gốm”.', 256),
    (97, 44, 19, 'Chào anh chị, tôi từng bàn giao các đầu việc dịch thuật và bản địa hóa theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 263),
    (98, 45, 9, 'Tôi làm về dịch thuật và bản địa hóa. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “hiệu đính hồ sơ giới thiệu xưởng nội thất”.', 22),
    (99, 45, 19, 'Chào anh chị, tôi từng bàn giao các đầu việc dịch thuật và bản địa hóa theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 24),
    (100, 45, 29, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “hiệu đính hồ sơ giới thiệu xưởng nội thất”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 26),
    (101, 46, 10, 'Chào anh chị, tôi từng bàn giao các đầu việc kiểm thử phần mềm theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 420),
    (102, 46, 20, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “kiểm thử luồng đặt vé triển lãm cuối tuần”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 432),
    (103, 47, 10, 'Chào anh chị, tôi từng bàn giao các đầu việc kiểm thử phần mềm theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 384),
    (104, 47, 20, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “viết bộ kiểm thử api cho cổng đặt lịch”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 394),
    (105, 47, 30, 'Tôi làm về kiểm thử phần mềm. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “viết bộ kiểm thử api cho cổng đặt lịch”.', 405),
    (106, 48, 10, 'Chào anh chị, tôi từng bàn giao các đầu việc kiểm thử phần mềm theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 24),
    (107, 48, 20, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “kiểm thử đa trình duyệt trang bán bánh”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 26),
    (108, 49, 10, 'Chào anh chị, tôi từng bàn giao các đầu việc kiểm thử phần mềm theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 26),
    (109, 49, 20, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “rà hồi quy hệ thống theo dõi hợp đồng”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 28),
    (110, 49, 30, 'Tôi làm về kiểm thử phần mềm. Tuần này tôi có thể đọc tài liệu và gửi bản nháp để hai bên chốt phạm vi “rà hồi quy hệ thống theo dõi hợp đồng”.', 30),
    (111, 50, 10, 'Chào anh chị, tôi từng bàn giao các đầu việc kiểm thử phần mềm theo mốc. Tôi đề xuất một buổi trao đổi ngắn trước khi bắt đầu để thống nhất kết quả cần nhận.', 320),
    (112, 50, 20, 'Tôi có thể bắt đầu với phần rà soát đầu vào, sau đó gửi kết quả từng đợt. Về việc “tạo dữ liệu kiểm thử cho tính năng xuất hóa đơn”, anh chị có tài liệu mẫu hoặc thời hạn cụ thể không?', 329)
) AS v(proposal_id, job_id, freelancer_id, cover_letter, offered_amount)
JOIN miniupwork.job AS j USING (job_id);

UPDATE miniupwork.proposal SET status = 'ACCEPTED' WHERE proposal_id IN (4,6,13,16,24,26,33,36,44,46,53,56);

UPDATE miniupwork.proposal SET status = 'REJECTED' WHERE proposal_id IN (5,7,8,14,15,17,25,27,28,34,35,37,45,47,48,54,55,57);

UPDATE miniupwork.proposal SET status = 'SHORTLISTED' WHERE status = 'SUBMITTED' AND proposal_id % 5 = 0;

UPDATE miniupwork.proposal SET status = 'WITHDRAWN' WHERE status = 'SUBMITTED' AND proposal_id % 7 = 0;

UPDATE miniupwork.job SET status = 'CANCELLED' WHERE job_id IN (4,9,14);

UPDATE miniupwork.job SET status = 'CLOSED' WHERE status = 'OPEN' AND job_id NOT IN (1,6,11,16,21,26,31,36,41,46);

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (1,4,'FIXED_PRICE',CURRENT_DATE - 44);

INSERT INTO miniupwork.fixed_price_contract VALUES (1,512);

INSERT INTO miniupwork.milestone (milestone_id,contract_id,sequence_no,title,amount,due_date) VALUES
            (11,1,1,'Bản triển khai để duyệt',215.04,CURRENT_DATE - 17),
            (12,1,2,'Hoàn thiện và bàn giao',296.96,CURRENT_DATE + 11);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=1;

INSERT INTO miniupwork.escrow_funding (funding_id,milestone_id,funded_amount,funded_at) VALUES (11,11,215.04,now() - interval '24 days');

UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=11;

UPDATE miniupwork.milestone SET status='SUBMITTED' WHERE milestone_id=11;

UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=11;

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (2,6,'HOURLY',CURRENT_DATE - 44);

INSERT INTO miniupwork.hourly_contract VALUES (2,24,20);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=2;

INSERT INTO miniupwork.weekly_invoice (invoice_id,contract_id,period_start) VALUES (2,2,((date_trunc('week', now(), 'UTC') - interval '14 days') AT TIME ZONE 'UTC')::date);

INSERT INTO miniupwork.time_entry (contract_id,invoice_id,start_at,end_at,description) VALUES
            (2,2,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 5 hours','Rà soát yêu cầu và tái hiện lỗi'),
            (2,2,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 6 hours','Triển khai và thử nghiệm với dữ liệu mẫu');

UPDATE miniupwork.weekly_invoice SET status='ISSUED' WHERE invoice_id=2;

UPDATE miniupwork.weekly_invoice SET status='APPROVED' WHERE invoice_id=2;

INSERT INTO miniupwork.time_entry (contract_id,start_at,end_at,description) VALUES (2,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '8 days 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '8 days 4 hours','Rà kết quả sau bàn giao tuần trước');

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (3,13,'FIXED_PRICE',CURRENT_DATE - 44);

INSERT INTO miniupwork.fixed_price_contract VALUES (3,375);

INSERT INTO miniupwork.milestone (milestone_id,contract_id,sequence_no,title,amount,due_date) VALUES
            (31,3,1,'Bản triển khai để duyệt',157.5,CURRENT_DATE - 17),
            (32,3,2,'Hoàn thiện và bàn giao',217.5,CURRENT_DATE + -8);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=3;

INSERT INTO miniupwork.escrow_funding (funding_id,milestone_id,funded_amount,funded_at) VALUES (31,31,157.5,now() - interval '24 days');

UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=31;

UPDATE miniupwork.milestone SET status='SUBMITTED' WHERE milestone_id=31;

UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=31;

INSERT INTO miniupwork.payment_transaction (contract_id,payer_id,payee_id,escrow_funding_id,transaction_type,amount,created_at) VALUES (3,38,2,31,'ESCROW_RELEASE',157.5,now() - interval '7 days');

INSERT INTO miniupwork.escrow_funding (funding_id,milestone_id,funded_amount,funded_at) VALUES (32,32,217.5,now() - interval '24 days');

UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=32;

UPDATE miniupwork.milestone SET status='SUBMITTED' WHERE milestone_id=32;

UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=32;

INSERT INTO miniupwork.payment_transaction (contract_id,payer_id,payee_id,escrow_funding_id,transaction_type,amount,created_at) VALUES (3,38,2,32,'ESCROW_RELEASE',217.5,now() - interval '7 days');

UPDATE miniupwork.contract SET status='COMPLETED',end_date=CURRENT_DATE-6 WHERE contract_id=3;

INSERT INTO miniupwork.review (contract_id,reviewer_id,reviewee_id,rating,comment,submitted_at) VALUES
            (3,38,2,5,'Bàn giao đúng phạm vi và giải thích rõ các bước cập nhật.',now() - interval '4 days'),
            (3,2,38,5,'Yêu cầu rõ ràng và phản hồi đúng các mốc đã thống nhất.',now() - interval '4 days');

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (4,16,'HOURLY',CURRENT_DATE - 44);

INSERT INTO miniupwork.hourly_contract VALUES (4,20,20);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=4;

INSERT INTO miniupwork.weekly_invoice (invoice_id,contract_id,period_start) VALUES (4,4,((date_trunc('week', now(), 'UTC') - interval '14 days') AT TIME ZONE 'UTC')::date);

INSERT INTO miniupwork.time_entry (contract_id,invoice_id,start_at,end_at,description) VALUES
            (4,4,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 5 hours','Rà soát yêu cầu và tái hiện lỗi'),
            (4,4,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 6 hours','Triển khai và thử nghiệm với dữ liệu mẫu');

UPDATE miniupwork.weekly_invoice SET status='ISSUED' WHERE invoice_id=4;

UPDATE miniupwork.weekly_invoice SET status='APPROVED' WHERE invoice_id=4;

INSERT INTO miniupwork.payment_transaction (contract_id,payer_id,payee_id,invoice_id,transaction_type,amount,created_at) VALUES (4,45,2,4,'HOURLY_CHARGE',140,now() - interval '7 days');

UPDATE miniupwork.contract SET status='COMPLETED',end_date=CURRENT_DATE-6 WHERE contract_id=4;

INSERT INTO miniupwork.review (contract_id,reviewer_id,reviewee_id,rating,comment,submitted_at) VALUES
            (4,45,2,4,'Bàn giao đúng phạm vi và giải thích rõ các bước cập nhật.',now() - interval '4 days'),
            (4,2,45,5,'Yêu cầu rõ ràng và phản hồi đúng các mốc đã thống nhất.',now() - interval '4 days');

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (5,24,'FIXED_PRICE',CURRENT_DATE - 44);

INSERT INTO miniupwork.fixed_price_contract VALUES (5,329);

INSERT INTO miniupwork.milestone (milestone_id,contract_id,sequence_no,title,amount,due_date) VALUES
            (51,5,1,'Bản triển khai để duyệt',138.18,CURRENT_DATE - 17),
            (52,5,2,'Hoàn thiện và bàn giao',190.82,CURRENT_DATE + 11);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=5;

INSERT INTO miniupwork.escrow_funding (funding_id,milestone_id,funded_amount,funded_at) VALUES (51,51,138.18,now() - interval '24 days');

UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=51;

UPDATE miniupwork.milestone SET status='SUBMITTED' WHERE milestone_id=51;

UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=51;

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (6,26,'HOURLY',CURRENT_DATE - 44);

INSERT INTO miniupwork.hourly_contract VALUES (6,24,20);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=6;

INSERT INTO miniupwork.weekly_invoice (invoice_id,contract_id,period_start) VALUES (6,6,((date_trunc('week', now(), 'UTC') - interval '14 days') AT TIME ZONE 'UTC')::date);

INSERT INTO miniupwork.time_entry (contract_id,invoice_id,start_at,end_at,description) VALUES
            (6,6,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 5 hours','Rà soát yêu cầu và tái hiện lỗi'),
            (6,6,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 6 hours','Triển khai và thử nghiệm với dữ liệu mẫu');

UPDATE miniupwork.weekly_invoice SET status='ISSUED' WHERE invoice_id=6;

UPDATE miniupwork.weekly_invoice SET status='APPROVED' WHERE invoice_id=6;

INSERT INTO miniupwork.payment_transaction (contract_id,payer_id,payee_id,invoice_id,transaction_type,amount,created_at) VALUES (6,45,3,6,'HOURLY_CHARGE',168,now() - interval '7 days');

UPDATE miniupwork.contract SET status='COMPLETED',end_date=CURRENT_DATE-6 WHERE contract_id=6;

INSERT INTO miniupwork.review (contract_id,reviewer_id,reviewee_id,rating,comment,submitted_at) VALUES
            (6,45,3,4,'Bàn giao đúng phạm vi và giải thích rõ các bước cập nhật.',now() - interval '4 days'),
            (6,3,45,5,'Yêu cầu rõ ràng và phản hồi đúng các mốc đã thống nhất.',now() - interval '4 days');

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (7,33,'FIXED_PRICE',CURRENT_DATE - 44);

INSERT INTO miniupwork.fixed_price_contract VALUES (7,228);

INSERT INTO miniupwork.milestone (milestone_id,contract_id,sequence_no,title,amount,due_date) VALUES
            (71,7,1,'Bản triển khai để duyệt',95.76,CURRENT_DATE - 17),
            (72,7,2,'Hoàn thiện và bàn giao',132.24,CURRENT_DATE + -8);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=7;

INSERT INTO miniupwork.escrow_funding (funding_id,milestone_id,funded_amount,funded_at) VALUES (71,71,95.76,now() - interval '24 days');

UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=71;

UPDATE miniupwork.milestone SET status='SUBMITTED' WHERE milestone_id=71;

UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=71;

INSERT INTO miniupwork.payment_transaction (contract_id,payer_id,payee_id,escrow_funding_id,transaction_type,amount,created_at) VALUES (7,44,4,71,'ESCROW_RELEASE',95.76,now() - interval '7 days');

INSERT INTO miniupwork.escrow_funding (funding_id,milestone_id,funded_amount,funded_at) VALUES (72,72,132.24,now() - interval '24 days');

UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=72;

UPDATE miniupwork.milestone SET status='SUBMITTED' WHERE milestone_id=72;

UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=72;

INSERT INTO miniupwork.payment_transaction (contract_id,payer_id,payee_id,escrow_funding_id,transaction_type,amount,created_at) VALUES (7,44,4,72,'ESCROW_RELEASE',132.24,now() - interval '7 days');

UPDATE miniupwork.contract SET status='COMPLETED',end_date=CURRENT_DATE-6 WHERE contract_id=7;

INSERT INTO miniupwork.review (contract_id,reviewer_id,reviewee_id,rating,comment,submitted_at) VALUES
            (7,44,4,5,'Bàn giao đúng phạm vi và giải thích rõ các bước cập nhật.',now() - interval '4 days'),
            (7,4,44,5,'Yêu cầu rõ ràng và phản hồi đúng các mốc đã thống nhất.',now() - interval '4 days');

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (8,36,'HOURLY',CURRENT_DATE - 44);

INSERT INTO miniupwork.hourly_contract VALUES (8,16,20);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=8;

INSERT INTO miniupwork.weekly_invoice (invoice_id,contract_id,period_start) VALUES (8,8,((date_trunc('week', now(), 'UTC') - interval '14 days') AT TIME ZONE 'UTC')::date);

INSERT INTO miniupwork.time_entry (contract_id,invoice_id,start_at,end_at,description) VALUES
            (8,8,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 5 hours','Rà soát yêu cầu và tái hiện lỗi'),
            (8,8,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 6 hours','Triển khai và thử nghiệm với dữ liệu mẫu');

UPDATE miniupwork.weekly_invoice SET status='ISSUED' WHERE invoice_id=8;

UPDATE miniupwork.weekly_invoice SET status='APPROVED' WHERE invoice_id=8;

INSERT INTO miniupwork.time_entry (contract_id,start_at,end_at,description) VALUES (8,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '8 days 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '8 days 4 hours','Rà kết quả sau bàn giao tuần trước');

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (9,44,'FIXED_PRICE',CURRENT_DATE - 44);

INSERT INTO miniupwork.fixed_price_contract VALUES (9,283);

INSERT INTO miniupwork.milestone (milestone_id,contract_id,sequence_no,title,amount,due_date) VALUES
            (91,9,1,'Bản triển khai để duyệt',118.86,CURRENT_DATE - 17),
            (92,9,2,'Hoàn thiện và bàn giao',164.14,CURRENT_DATE + -8);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=9;

INSERT INTO miniupwork.escrow_funding (funding_id,milestone_id,funded_amount,funded_at) VALUES (91,91,118.86,now() - interval '24 days');

UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=91;

UPDATE miniupwork.milestone SET status='SUBMITTED' WHERE milestone_id=91;

UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=91;

INSERT INTO miniupwork.payment_transaction (contract_id,payer_id,payee_id,escrow_funding_id,transaction_type,amount,created_at) VALUES (9,48,5,91,'ESCROW_RELEASE',118.86,now() - interval '7 days');

INSERT INTO miniupwork.escrow_funding (funding_id,milestone_id,funded_amount,funded_at) VALUES (92,92,164.14,now() - interval '24 days');

UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=92;

UPDATE miniupwork.milestone SET status='SUBMITTED' WHERE milestone_id=92;

UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=92;

INSERT INTO miniupwork.payment_transaction (contract_id,payer_id,payee_id,escrow_funding_id,transaction_type,amount,created_at) VALUES (9,48,5,92,'ESCROW_RELEASE',164.14,now() - interval '7 days');

UPDATE miniupwork.contract SET status='COMPLETED',end_date=CURRENT_DATE-6 WHERE contract_id=9;

INSERT INTO miniupwork.review (contract_id,reviewer_id,reviewee_id,rating,comment,submitted_at) VALUES
            (9,48,5,5,'Bàn giao đúng phạm vi và giải thích rõ các bước cập nhật.',now() - interval '4 days'),
            (9,5,48,5,'Yêu cầu rõ ràng và phản hồi đúng các mốc đã thống nhất.',now() - interval '4 days');

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (10,46,'HOURLY',CURRENT_DATE - 44);

INSERT INTO miniupwork.hourly_contract VALUES (10,25,20);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=10;

INSERT INTO miniupwork.weekly_invoice (invoice_id,contract_id,period_start) VALUES (10,10,((date_trunc('week', now(), 'UTC') - interval '14 days') AT TIME ZONE 'UTC')::date);

INSERT INTO miniupwork.time_entry (contract_id,invoice_id,start_at,end_at,description) VALUES
            (10,10,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 5 hours','Rà soát yêu cầu và tái hiện lỗi'),
            (10,10,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 6 hours','Triển khai và thử nghiệm với dữ liệu mẫu');

UPDATE miniupwork.weekly_invoice SET status='ISSUED' WHERE invoice_id=10;

UPDATE miniupwork.weekly_invoice SET status='APPROVED' WHERE invoice_id=10;

INSERT INTO miniupwork.time_entry (contract_id,start_at,end_at,description) VALUES (10,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '8 days 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '8 days 4 hours','Rà kết quả sau bàn giao tuần trước');

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (11,53,'FIXED_PRICE',CURRENT_DATE - 44);

INSERT INTO miniupwork.fixed_price_contract VALUES (11,402);

INSERT INTO miniupwork.milestone (milestone_id,contract_id,sequence_no,title,amount,due_date) VALUES
            (111,11,1,'Bản triển khai để duyệt',168.84,CURRENT_DATE - 17),
            (112,11,2,'Hoàn thiện và bàn giao',233.16,CURRENT_DATE + 11);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=11;

INSERT INTO miniupwork.escrow_funding (funding_id,milestone_id,funded_amount,funded_at) VALUES (111,111,168.84,now() - interval '24 days');

UPDATE miniupwork.milestone SET status='FUNDED' WHERE milestone_id=111;

UPDATE miniupwork.milestone SET status='SUBMITTED' WHERE milestone_id=111;

UPDATE miniupwork.milestone SET status='APPROVED' WHERE milestone_id=111;

INSERT INTO miniupwork.contract (contract_id,proposal_id,contract_type,start_date) VALUES (12,56,'HOURLY',CURRENT_DATE - 44);

INSERT INTO miniupwork.hourly_contract VALUES (12,30,20);

UPDATE miniupwork.contract SET status='ACTIVE' WHERE contract_id=12;

INSERT INTO miniupwork.weekly_invoice (invoice_id,contract_id,period_start) VALUES (12,12,((date_trunc('week', now(), 'UTC') - interval '14 days') AT TIME ZONE 'UTC')::date);

INSERT INTO miniupwork.time_entry (contract_id,invoice_id,start_at,end_at,description) VALUES
            (12,12,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '1 day 5 hours','Rà soát yêu cầu và tái hiện lỗi'),
            (12,12,(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 2 hours',(date_trunc('week', now(), 'UTC') - interval '14 days') + interval '3 days 6 hours','Triển khai và thử nghiệm với dữ liệu mẫu');

UPDATE miniupwork.weekly_invoice SET status='ISSUED' WHERE invoice_id=12;

UPDATE miniupwork.weekly_invoice SET status='APPROVED' WHERE invoice_id=12;

INSERT INTO miniupwork.payment_transaction (contract_id,payer_id,payee_id,invoice_id,transaction_type,amount,created_at) VALUES (12,50,6,12,'HOURLY_CHARGE',210,now() - interval '7 days');

UPDATE miniupwork.contract SET status='COMPLETED',end_date=CURRENT_DATE-6 WHERE contract_id=12;

INSERT INTO miniupwork.review (contract_id,reviewer_id,reviewee_id,rating,comment,submitted_at) VALUES
            (12,50,6,4,'Bàn giao đúng phạm vi và giải thích rõ các bước cập nhật.',now() - interval '4 days'),
            (12,6,50,5,'Yêu cầu rõ ràng và phản hồi đúng các mốc đã thống nhất.',now() - interval '4 days');

SELECT setval(pg_get_serial_sequence('miniupwork.app_user','user_id'), max(user_id)) FROM miniupwork.app_user;

SELECT setval(pg_get_serial_sequence('miniupwork.category','category_id'), max(category_id)) FROM miniupwork.category;

SELECT setval(pg_get_serial_sequence('miniupwork.skill','skill_id'), max(skill_id)) FROM miniupwork.skill;

SELECT setval(pg_get_serial_sequence('miniupwork.job','job_id'), max(job_id)) FROM miniupwork.job;

SELECT setval(pg_get_serial_sequence('miniupwork.proposal','proposal_id'), max(proposal_id)) FROM miniupwork.proposal;

SELECT setval(pg_get_serial_sequence('miniupwork.contract','contract_id'), max(contract_id)) FROM miniupwork.contract;

SELECT setval(pg_get_serial_sequence('miniupwork.milestone','milestone_id'), max(milestone_id)) FROM miniupwork.milestone;

SELECT setval(pg_get_serial_sequence('miniupwork.escrow_funding','funding_id'), max(funding_id)) FROM miniupwork.escrow_funding;

SELECT setval(pg_get_serial_sequence('miniupwork.weekly_invoice','invoice_id'), max(invoice_id)) FROM miniupwork.weekly_invoice;

SET CONSTRAINTS ALL IMMEDIATE;

COMMIT;
