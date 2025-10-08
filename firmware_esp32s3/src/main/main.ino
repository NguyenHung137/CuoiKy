/*
 * ESP32-S3 IoT Demo Firmware
 * Nâng cấp để điều khiển Motor DC qua L298N
 */

#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include <DHT.h>

// =============================================================================
// CONFIGURATION
// =============================================================================

// WiFi Configuration
const char* WIFI_SSID = "TDMU";
const char* WIFI_PASSWORD = "";

// MQTT Broker Configuration
const char* MQTT_HOST = "10.15.175.192";
const int MQTT_PORT = 1883;
const char* MQTT_USERNAME = "user1";
const char* MQTT_PASSWORD = "pass1";

// NTP Server Configuration
const char* NTP_SERVER = "pool.ntp.org";
const long GMT_OFFSET_SEC = 7 * 3600;
const int DAYLIGHT_OFFSET_SEC = 0;

// Device Configuration
const char* DEVICE_ID = "esp32_demo_001";
const char* FIRMWARE_VERSION = "demo1-1.0.4-L298N-analogWrite"; // Firmware version (updated for L298N)
const char* TOPIC_NS = "lab/room1";

// =============================================================================
// GPIO PIN CONFIGURATION (SỬA ĐỔI CHO L298N)
// =============================================================================
const int LIGHT_RELAY_PIN = 10;   // GPIO cho đèn (chọn chân khác nếu cần)
const int STATUS_LED_PIN  = 2;
const int DHT_PIN         = 4;

// --- Chân điều khiển Motor ---
const int MOTOR_ENA_PIN   = 5;    // Chân tốc độ (phải hỗ trợ PWM)
const int MOTOR_IN1_PIN   = 6;    // Chân chiều quay 1
const int MOTOR_IN2_PIN   = 7;    // Chân chiều quay 2
// =============================================================================

// Timing Configuration
const unsigned long SENSOR_PUBLISH_INTERVAL = 3000;
const unsigned long HEARTBEAT_INTERVAL = 15000;
const unsigned long WIFI_RECONNECT_INTERVAL = 5000;
const unsigned long MQTT_RECONNECT_INTERVAL = 5000;
const unsigned long COMMAND_DEBOUNCE_DELAY = 500;

// Global variables...
WiFiClient espClient;
PubSubClient mqttClient(espClient);
DHT dht(DHT_PIN, DHT22);

bool lightState = false;
bool fanState = false; // Vẫn dùng biến này để biết motor đang BẬT hay TẮT
bool deviceOnline = false;

// ... (Các biến timing và topic giữ nguyên)
unsigned long lastSensorPublish = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastWifiCheck = 0;
unsigned long lastMqttCheck = 0;
unsigned long lastCommandTime = 0;
String topicSensorState;
String topicDeviceState;
String topicDeviceCmd;
String topicSysOnline;

// Forward declarations
void initNTP();
void onMqttMessage(char* topic, byte* payload, unsigned int length);
void connectMQTT();
void publishDeviceState();
void publishOnlineStatus(bool online);
void publishSensorData();
void controlMotor(bool turnOn);

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== ESP32 IoT Demo (L298N Motor Control) ===");
  initGPIO();
  dht.begin();
  Serial.println("DHT22 sensor initialized.");
  
  // Không cần cấu hình PWM phức tạp khi dùng analogWrite
  Serial.println("Using analogWrite for motor speed control.");

  initTopics();
  initWiFi();
  initNTP();
  initMQTT();
  Serial.println("=== Setup Complete ===\n");
}

void loop() {
  // ... (Hàm loop giữ nguyên, không cần sửa)
  unsigned long currentTime = millis();
  checkWiFi(currentTime);
  checkMQTT(currentTime);
  if (mqttClient.connected()) {
    mqttClient.loop();
    if (currentTime - lastSensorPublish >= SENSOR_PUBLISH_INTERVAL) {
      publishSensorData();
      lastSensorPublish = currentTime;
    }
    if (currentTime - lastHeartbeat >= HEARTBEAT_INTERVAL) {
      publishDeviceState();
      lastHeartbeat = currentTime;
    }
  }
  updateStatusLED();
  delay(100);
}

// =============================================================================
// SỬA ĐỔI: HÀM ĐIỀU KHIỂN MOTOR
// =============================================================================
void controlMotor(bool turnOn) {
    if (turnOn) {
        Serial.println("Turning motor ON (Forward, Full Speed)");
        // Quay thuận: IN1=HIGH, IN2=LOW
        digitalWrite(MOTOR_IN1_PIN, HIGH);
        digitalWrite(MOTOR_IN2_PIN, LOW);
        // Chạy tốc độ tối đa (0-255)
        analogWrite(MOTOR_ENA_PIN, 255); 
    } else {
        Serial.println("Turning motor OFF");
        // Dừng motor: IN1=LOW, IN2=LOW
        digitalWrite(MOTOR_IN1_PIN, LOW);
        digitalWrite(MOTOR_IN2_PIN, LOW);
        // Tốc độ bằng 0
        analogWrite(MOTOR_ENA_PIN, 0);
    }
}


// =============================================================================
// SỬA ĐỔI: XỬ LÝ LỆNH MQTT
// =============================================================================
void handleDeviceCommand(String message) {
  // ... (Phần debounce và parse JSON giữ nguyên)
  unsigned long currentTime = millis();
  if (currentTime - lastCommandTime < COMMAND_DEBOUNCE_DELAY) {
    Serial.println("Command ignored due to debounce");
    return;
  }
  lastCommandTime = currentTime;
  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, message);
  if (error) {
    Serial.printf("JSON parse error: %s\n", error.c_str());
    return;
  }
  
  bool stateChanged = false;

  // Xử lý lệnh đèn (giữ nguyên)
  if (doc.containsKey("light")) {
    String lightCmd = doc["light"].as<String>();
    if (lightCmd.equalsIgnoreCase("on")) {
        lightState = true;
        stateChanged = true;
    } else if (lightCmd.equalsIgnoreCase("off")) {
        lightState = false;
        stateChanged = true;
    } else if (lightCmd.equalsIgnoreCase("toggle")) {
      lightState = !lightState;
      stateChanged = true;
    }
    digitalWrite(LIGHT_RELAY_PIN, lightState ? HIGH : LOW);
    Serial.printf("Light turned %s\n", lightState ? "ON" : "OFF");
  }
  
  // SỬA ĐỔI: Xử lý lệnh "fan" (nay là motor)
  if (doc.containsKey("fan")) {
    String fanCmd = doc["fan"].as<String>();
    Serial.printf("Motor command: %s\n", fanCmd.c_str());
    
    if (fanCmd.equalsIgnoreCase("on")) {
        fanState = true;
        stateChanged = true;
    } else if (fanCmd.equalsIgnoreCase("off")) {
        fanState = false;
        stateChanged = true;
    } else if (fanCmd.equalsIgnoreCase("toggle")) {
        fanState = !fanState;
        stateChanged = true;
    }
    
    // Gọi hàm điều khiển motor
    controlMotor(fanState);
  }
  
  if (stateChanged) {
    publishDeviceState();
  }
}

// ... (Các hàm còn lại như initGPIO, initWiFi, publishSensorData... giữ nguyên hoặc đã được tích hợp ở trên)
void initGPIO() {
  Serial.println("Initializing GPIO pins...");
  pinMode(LIGHT_RELAY_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  
  // SỬA ĐỔI: Cấu hình chân motor
  pinMode(MOTOR_IN1_PIN, OUTPUT);
  pinMode(MOTOR_IN2_PIN, OUTPUT);
  // analogWrite tự xử lý pinMode cho chân ENA
  
  digitalWrite(LIGHT_RELAY_PIN, LOW);
  digitalWrite(STATUS_LED_PIN, LOW);
  
  // SỬA ĐỔI: Đảm bảo motor dừng khi khởi động
  digitalWrite(MOTOR_IN1_PIN, LOW);
  digitalWrite(MOTOR_IN2_PIN, LOW);

  Serial.printf("Light relay pin: %d\n", LIGHT_RELAY_PIN);
  Serial.printf("Status LED pin: %d\n", STATUS_LED_PIN);
  Serial.printf("Motor pins: ENA=%d, IN1=%d, IN2=%d\n", MOTOR_ENA_PIN, MOTOR_IN1_PIN, MOTOR_IN2_PIN);
}

// ... (Sao chép toàn bộ các hàm còn lại không thay đổi từ code cũ của bạn vào đây)
// Các hàm cần sao chép:
// initTopics(), initWiFi(), initNTP(), initMQTT(), checkWiFi(), checkMQTT(), 
// connectMQTT(), onMqttMessage(), publishSensorData(), publishDeviceState(),
// publishOnlineStatus(), updateStatusLED()
void initTopics() {
  Serial.println("Initializing MQTT topics...");
  topicSensorState = String(TOPIC_NS) + "/sensor/state";
  topicDeviceState = String(TOPIC_NS) + "/device/state";
  topicDeviceCmd = String(TOPIC_NS) + "/device/cmd";
  topicSysOnline = String(TOPIC_NS) + "/sys/online";
  Serial.printf("Sensor topic: %s\n", topicSensorState.c_str());
  Serial.printf("Device state topic: %s\n", topicDeviceState.c_str());
  Serial.printf("Command topic: %s\n", topicDeviceCmd.c_str());
  Serial.printf("Online topic: %s\n", topicSysOnline.c_str());
}
void initWiFi() {
  Serial.printf("Connecting to WiFi: %s\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\nWiFi connected! IP: %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("RSSI: %d dBm\n", WiFi.RSSI());
  } else {
    Serial.println("\nWiFi connection failed!");
  }
}
void initNTP() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Cannot initialize NTP, WiFi not connected.");
    return;
  }
  Serial.println("Initializing NTP client...");
  configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER);
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return;
  }
  Serial.println("NTP time synchronized successfully.");
  Serial.println(&timeinfo, "%A, %B %d %Y %H:%M:%S");
}
void initMQTT() {
  Serial.printf("Setting up MQTT client for %s:%d\n", MQTT_HOST, MQTT_PORT);
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(onMqttMessage);
  mqttClient.setKeepAlive(30);
  mqttClient.setSocketTimeout(5);
  connectMQTT();
}
// THAY THẾ HÀM checkWiFi CŨ BẰNG HÀM NÀY
void checkWiFi(unsigned long currentTime) {
  if (currentTime - lastWifiCheck < WIFI_RECONNECT_INTERVAL) return;
  lastWifiCheck = currentTime;

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Attempting to reconnect...");
    // Dùng WiFi.reconnect() thay vì WiFi.begin() để tránh xung đột
    WiFi.reconnect(); 
  }
}
void checkMQTT(unsigned long currentTime) {
  if (currentTime - lastMqttCheck < MQTT_RECONNECT_INTERVAL) return;
  lastMqttCheck = currentTime;
  if (WiFi.status() == WL_CONNECTED && !mqttClient.connected()) {
    Serial.println("MQTT disconnected. Reconnecting...");
    connectMQTT();
  }
}
void connectMQTT() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, skipping MQTT connection");
    return;
  }
  Serial.printf("Connecting to MQTT broker: %s:%d\n", MQTT_HOST, MQTT_PORT);
  String lwt = "{\"online\":false}";
  bool connected = mqttClient.connect(DEVICE_ID, MQTT_USERNAME, MQTT_PASSWORD, topicSysOnline.c_str(), 1, true, lwt.c_str());
  if (connected) {
    Serial.println("MQTT connected successfully!");
    if (mqttClient.subscribe(topicDeviceCmd.c_str(), 1)) {
      Serial.printf("Subscribed to: %s\n", topicDeviceCmd.c_str());
    } else {
      Serial.println("Failed to subscribe to command topic!");
    }
    publishOnlineStatus(true);
    publishDeviceState();
    deviceOnline = true;
  } else {
    Serial.printf("MQTT connection failed! State: %d\n", mqttClient.state());
    deviceOnline = false;
  }
}
void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  String message = "";
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.printf("Received [%s]: %s\n", topic, message.c_str());
  if (String(topic) == topicDeviceCmd) {
    handleDeviceCommand(message);
  }
}
void publishSensorData() {
  if (!mqttClient.connected()) return;
  float humidity = dht.readHumidity();
  float temperature = dht.readTemperature();
  if (isnan(humidity) || isnan(temperature)) {
    Serial.println("Failed to read from DHT sensor!");
    return;
  }
  int lightLevel = 100 + random(-50, 200);
  JsonDocument doc;
  doc["ts"] = time(nullptr);
  doc["temp_c"] = round(temperature * 10) / 10.0;
  doc["hum_pct"] = round(humidity * 10) / 10.0;
  doc["lux"] = lightLevel;
  String payload;
  serializeJson(doc, payload);
  if (mqttClient.publish(topicSensorState.c_str(), payload.c_str(), false)) {
    Serial.printf("Sensor data published: %s\n", payload.c_str());
  } else {
    Serial.println("Failed to publish sensor data!");
  }
}
void publishDeviceState() {
  if (!mqttClient.connected()) return;
  JsonDocument doc;
  doc["ts"] = time(nullptr);
  doc["light"] = lightState ? "on" : "off";
  doc["fan"] = fanState ? "on" : "off";
  doc["rssi"] = WiFi.RSSI();
  doc["fw"] = FIRMWARE_VERSION;
  String payload;
  serializeJson(doc, payload);
  if (mqttClient.publish(topicDeviceState.c_str(), payload.c_str(), true)) {
    Serial.printf("Device state published: %s\n", payload.c_str());
  } else {
    Serial.println("Failed to publish device state!");
  }
}
void publishOnlineStatus(bool online) {
  if (!mqttClient.connected()) return;
  JsonDocument doc;
  doc["online"] = online;
  String payload;
  serializeJson(doc, payload);
  if (mqttClient.publish(topicSysOnline.c_str(), payload.c_str(), true)) {
    Serial.printf("Online status published: %s\n", payload.c_str());
  } else {
    Serial.println("Failed to publish online status!");
  }
}
void updateStatusLED() {
  static unsigned long lastBlink = 0;
  static bool ledState = false;
  unsigned long currentTime = millis();
  if (WiFi.status() == WL_CONNECTED && mqttClient.connected()) {
    digitalWrite(STATUS_LED_PIN, HIGH);
  } else if (WiFi.status() == WL_CONNECTED) {
    if (currentTime - lastBlink >= 250) {
      ledState = !ledState;
      digitalWrite(STATUS_LED_PIN, ledState ? HIGH : LOW);
      lastBlink = currentTime;
    }
  } else {
    if (currentTime - lastBlink >= 1000) {
      ledState = !ledState;
      digitalWrite(STATUS_LED_PIN, ledState ? HIGH : LOW);
      lastBlink = currentTime;
    }
  }
}
