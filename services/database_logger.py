# Import các thư viện cần thiết
import paho.mqtt.client as mqtt
import psycopg2
import json
import os
import time

# --- CẤU HÌNH ---
# Lấy thông tin từ biến môi trường, hoặc dùng giá trị mặc định
MQTT_HOST = os.getenv('MQTT_HOST', 'localhost')
MQTT_PORT = int(os.getenv('MQTT_PORT', 1883))
MQTT_USERNAME = os.getenv('MQTT_USERNAME', 'user1')
MQTT_PASSWORD = os.getenv('MQTT_PASSWORD', 'pass1')
TOPIC_NAMESPACE = os.getenv('TOPIC_NAMESPACE', 'lab/room1')

DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = int(os.getenv('DB_PORT', 5432))
DB_NAME = os.getenv('DB_NAME', 'iot_final_project') # Sửa tên database cho đúng
DB_USER = os.getenv('DB_USER', 'postgres')
# === THAY MẬT KHẨU CỦA BẠN VÀO ĐÂY ===
DB_PASSWORD = os.getenv('DB_PASSWORD', '1')     

# --- KẾT NỐI DATABASE ---
def get_db_connection():
    """Hàm kết nối tới PostgreSQL với cơ chế thử lại."""
    conn = None
    while conn is None:
        try:
            print("Connecting to PostgreSQL database...")
            conn = psycopg2.connect(
                host=DB_HOST,
                port=DB_PORT,
                dbname=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD
            )
            print("PostgreSQL connection successful!")
        except psycopg2.OperationalError as e:
            print(f"Connection failed: {e}. Retrying in 5 seconds...")
            time.sleep(5)
    return conn

# --- CÁC HÀM XỬ LÝ MQTT ---
def on_connect(client, userdata, flags, rc):
    """Callback được gọi khi kết nối MQTT thành công."""
    if rc == 0:
        print("Connected to MQTT Broker!")
        # Lắng nghe topic dữ liệu cảm biến và trạng thái thiết bị
        client.subscribe(f"{TOPIC_NAMESPACE}/sensor/state")
        client.subscribe(f"{TOPIC_NAMESPACE}/device/state")
        print(f"Subscribed to topics under '{TOPIC_NAMESPACE}'")
    else:
        print(f"Failed to connect, return code {rc}\n")

def on_message(client, userdata, msg):
    """Callback được gọi khi có tin nhắn mới từ MQTT."""
    topic = msg.topic
    payload = msg.payload.decode('utf-8')
    print(f"Received message on topic '{topic}': {payload}")

    try:
        data = json.loads(payload)
        
        # Kiểm tra topic để quyết định lưu vào bảng nào
        if topic.endswith('/sensor/state'):
            save_sensor_data(data)
        elif topic.endswith('/device/state'):
            save_device_event(data)
            
    except json.JSONDecodeError:
        print("Error: Could not decode JSON payload.")
    except Exception as e:
        print(f"An error occurred: {e}")

# --- CÁC HÀM GHI DỮ LIỆU VÀO DATABASE ---
db_conn = get_db_connection()
# Sử dụng một biến toàn cục để kiểm tra trạng thái trước đó
last_known_states = {"light": None, "fan": None}

def save_sensor_data(data):
    """Lưu dữ liệu nhiệt độ, độ ẩm vào bảng sensor_data."""
    try:
        temp = data.get('temp_c')
        humidity = data.get('hum_pct')

        if temp is not None and humidity is not None:
            with db_conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO sensor_data (temperature, humidity) VALUES (%s, %s)",
                    (temp, humidity)
                )
            db_conn.commit()
            print(f"Saved sensor data: Temp={temp}, Humidity={humidity}")
    except Exception as e:
        print(f"Error saving sensor data: {e}")
        db_conn.rollback()

def save_device_event(data):
    """Chỉ lưu sự kiện bật/tắt khi trạng thái thay đổi."""
    global last_known_states
    try:
        state_changed = False
        with db_conn.cursor() as cur:
            # Kiểm tra trạng thái đèn
            light_state = data.get('light')
            if light_state is not None and light_state != last_known_states.get('light'):
                cur.execute(
                    "INSERT INTO device_events (device, event) VALUES (%s, %s)",
                    ('light', light_state)
                )
                last_known_states['light'] = light_state
                state_changed = True
                print(f"Saved event: Light changed to {light_state}")

            # Kiểm tra trạng thái quạt
            fan_state = data.get('fan')
            if fan_state is not None and fan_state != last_known_states.get('fan'):
                cur.execute(
                    "INSERT INTO device_events (device, event) VALUES (%s, %s)",
                    ('fan', fan_state)
                )
                last_known_states['fan'] = fan_state
                state_changed = True
                print(f"Saved event: Fan changed to {fan_state}")
        
        if state_changed:
            db_conn.commit()

    except Exception as e:
        print(f"Error saving device event: {e}")
        db_conn.rollback()


# --- KHỞI CHẠY CHÍNH ---
if __name__ == "__main__":
    client = mqtt.Client(client_id="database_logger_service")
    client.username_pw_set(MQTT_USERNAME, MQTT_PASSWORD)
    client.on_connect = on_connect
    client.on_message = on_message

    print("Connecting to MQTT Broker...")
    client.connect(MQTT_HOST, MQTT_PORT, 60)

    # Bắt đầu vòng lặp để lắng nghe tin nhắn
    try:
        client.loop_forever()
    except KeyboardInterrupt:
        print("Logger service stopped.")
        if db_conn:
            db_conn.close()
            print("Database connection closed.")
