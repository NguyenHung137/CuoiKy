-- Xóa các bảng cũ nếu chúng tồn tại để đảm bảo làm mới
DROP TABLE IF EXISTS device_events;
DROP TABLE IF EXISTS sensor_data;

-- Bảng 1: Lưu trữ dữ liệu cảm biến theo thời gian
-- Bảng này sẽ có một dòng mới mỗi khi ESP32 gửi dữ liệu.
CREATE TABLE sensor_data (
    -- 'id' là một số tự tăng, dùng làm khóa chính
    id SERIAL PRIMARY KEY,
    
    -- 'timestamp' tự động ghi lại thời gian khi một dòng mới được thêm vào
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Cột lưu giá trị nhiệt độ, cho phép lưu số thập phân
    temperature NUMERIC(5, 2),
    
    -- Cột lưu giá trị độ ẩm, cho phép lưu số thập phân
    humidity NUMERIC(5, 2)
);

-- Bảng 2: Lưu trữ các sự kiện bật/tắt của thiết bị
-- Bảng này chỉ có một dòng mới khi trạng thái của đèn hoặc quạt THAY ĐỔI.
CREATE TABLE device_events (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Tên của thiết bị (ví dụ: 'light' hoặc 'fan')
    device VARCHAR(50) NOT NULL,
    
    -- Trạng thái mới của thiết bị (ví dụ: 'on' hoặc 'off')
    event VARCHAR(50) NOT NULL
);

-- Thêm một vài dòng dữ liệu mẫu để bạn có thể kiểm tra ngay lập tức
INSERT INTO sensor_data (temperature, humidity) VALUES (28.5, 75.2);
INSERT INTO sensor_data (temperature, humidity) VALUES (28.7, 75.5);
INSERT INTO device_events (device, event) VALUES ('light', 'on');
INSERT INTO device_events (device, event) VALUES ('fan', 'on');

-- Thông báo trong log của PostgreSQL để biết script đã chạy thành công
DO $$
BEGIN
   RAISE NOTICE 'Database tables created and sample data inserted successfully!';
END $$;

