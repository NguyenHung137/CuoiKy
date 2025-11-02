/*
 * ESP32 IoT Demo Firmware
 * Nâng cấp với tính năng Tự động hóa và Hẹn giờ
 */

#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <time.h>
#include <DHT.h>
#include <Preferences.h> // <-- THƯ VIỆN MỚI để lưu trữ

// =============================================================================
// CONFIGURATION
// =============================================================================

// WiFi Configuration
const char* WIFI_SSID = "Hoi Coffee 1";
const char* WIFI_PASSWORD = "12356789";

// MQTT Broker Configuration
const char* MQTT_HOST = "192.168.1.216";
const int MQTT_PORT = 1883;
const char* MQTT_USERNAME = "user1";
const char* MQTT_PASSWORD = "pass1";

// NTP Server Configuration
const char* NTP_SERVER = "pool.ntp.org";
const long GMT_OFFSET_SEC = 7 * 3600;
const int DAYLIGHT_OFFSET_SEC = 0;

// Device Configuration
const char* DEVICE_ID = "esp32_demo_001";
const char* FIRMWARE_VERSION = "demo1-1.0.6-Scheduling"; // Cập nhật phiên bản
const char* TOPIC_NS = "lab/room1";

// =============================================================================
// GPIO PIN CONFIGURATION
// =============================================================================
const int LIGHT_PIN       = 10;
const int STATUS_LED_PIN  = 2;
const int DHT_PIN         = 4;
const int MOTOR_ENA_PIN   = 5;
const int MOTOR_IN1_PIN   = 6;
const int MOTOR_IN2_PIN   = 7;

// =============================================================================
// TIMING & OTHER CONSTANTS
// =============================================================================
const unsigned long SENSOR_PUBLISH_INTERVAL = 3000;
const unsigned long HEARTBEAT_INTERVAL = 15000;
const unsigned long WIFI_RECONNECT_INTERVAL = 5000;
const unsigned long MQTT_RECONNECT_INTERVAL = 5000;
const unsigned long COMMAND_DEBOUNCE_DELAY = 500;

// =============================================================================
// GLOBAL VARIABLES & STRUCTURES
// =============================================================================

// Thư viện & Client
WiFiClient espClient;
PubSubClient mqttClient(espClient);
DHT dht(DHT_PIN, DHT22);
Preferences preferences; // Đối tượng để truy cập bộ nhớ lưu trữ

// Biến trạng thái
bool lightState = false;
bool fanState = false;
bool deviceOnline = false;
bool autoModeEnabled = true;

// Cấu trúc để lưu trữ lịch trình cho một thiết bị
struct DeviceSchedule {
    int on_hour = -1; // -1 nghĩa là chưa được đặt
    int on_minute = -1;
    int off_hour = -1;
    int off_minute = -1;
};
DeviceSchedule lightSchedule;
DeviceSchedule fanSchedule;

// Biến thời gian
unsigned long lastSensorPublish = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastWifiCheck = 0;
unsigned long lastMqttCheck = 0;
unsigned long lastCommandTime = 0;
unsigned long lastScheduleCheck = 0;

// Biến Topic
String topicSensorState, topicDeviceState, topicDeviceCmd, topicSysOnline, topicScheduleSet;

// Khai báo trước các hàm (Forward Declarations)
void initNTP();
void onMqttMessage(char* topic, byte* payload, unsigned int length);
void connectMQTT();
void publishDeviceState();
void controlMotor(bool turnOn);
void checkAutomation(float temperature);
void loadSchedules();
void checkSchedules();
void initGPIO();
void initTopics();
void initWiFi();
void initMQTT();
void checkWiFi(unsigned long currentTime);
void checkMQTT(unsigned long currentTime);
void publishOnlineStatus(bool online);
void updateStatusLED();
void handleDeviceCommand(String message);
void saveSchedule(const char* device, JsonObject scheduleData);


void setup() {
  Serial.begin(115220);
  delay(1000);
  
  Serial.println("\n=== ESP32 IoT Demo (Automation + Scheduling) ===");
  initGPIO();
  dht.begin();
  
  // TÍNH NĂNG MỚI: Đọc lịch trình đã lưu khi khởi động
  loadSchedules();

  initTopics();
  initWiFi();
  initNTP();
  initMQTT();
  Serial.println("=== Setup Complete ===\n");
}

void loop() {
  unsigned long currentTime = millis();
  checkWiFi(currentTime);
  checkMQTT(currentTime);

  if (mqttClient.connected()) {
    mqttClient.loop();
    
    // Kiểm tra lịch trình sau mỗi giây
    if (currentTime - lastScheduleCheck >= 1000) {
        checkSchedules();
        lastScheduleCheck = currentTime;
    }

    // Gửi dữ liệu cảm biến định kỳ
    if (currentTime - lastSensorPublish >= SENSOR_PUBLISH_INTERVAL) {
      publishSensorData();
      lastSensorPublish = currentTime;
    }
    
    // Gửi heartbeat định kỳ
    if (currentTime - lastHeartbeat >= HEARTBEAT_INTERVAL) {
      publishDeviceState();
      lastHeartbeat = currentTime;
    }
  }
  updateStatusLED();
  delay(100);
}

// =============================================================================
// CÁC HÀM MỚI CHO TÍNH NĂNG HẸN GIỜ
// =============================================================================

void loadSchedules() {
    preferences.begin("schedules", true); // Mở namespace 'schedules' ở chế độ chỉ đọc
    
    lightSchedule.on_hour = preferences.getInt("l_on_h", -1);
    lightSchedule.on_minute = preferences.getInt("l_on_m", -1);
    lightSchedule.off_hour = preferences.getInt("l_off_h", -1);
    lightSchedule.off_minute = preferences.getInt("l_off_m", -1);

    fanSchedule.on_hour = preferences.getInt("f_on_h", -1);
    fanSchedule.on_minute = preferences.getInt("f_on_m", -1);
    fanSchedule.off_hour = preferences.getInt("f_off_h", -1);
    fanSchedule.off_minute = preferences.getInt("f_off_m", -1);

    Serial.println("Loaded schedules from memory.");
    preferences.end();
}

void saveSchedule(const char* device, JsonObject scheduleData) {
    preferences.begin("schedules", false); // Mở namespace ở chế độ ghi

    String prefix = (strcmp(device, "light") == 0) ? "l_" : "f_";

    preferences.putInt((prefix + "on_h").c_str(), scheduleData["on_hour"]);
    preferences.putInt((prefix + "on_m").c_str(), scheduleData["on_minute"]);
    preferences.putInt((prefix + "off_h").c_str(), scheduleData["off_hour"]);
    preferences.putInt((prefix + "off_m").c_str(), scheduleData["off_minute"]);

    Serial.printf("Saved new schedule for %s\n", device);
    preferences.end();
    
    // Tải lại lịch trình vào bộ nhớ RAM để áp dụng ngay
    loadSchedules();
}

void checkSchedules() {
    struct tm timeinfo;
    if (!getLocalTime(&timeinfo)) {
        return; // Không có thời gian thực, không thể kiểm tra lịch
    }

    int currentHour = timeinfo.tm_hour;
    int currentMinute = timeinfo.tm_min;

    // --- Kiểm tra lịch của đèn ---
    if (lightSchedule.on_hour != -1 && currentHour == lightSchedule.on_hour && currentMinute == lightSchedule.on_minute) {
        if (!lightState) {
            Serial.println("SCHEDULE: Turning light ON");
            lightState = true;
            digitalWrite(LIGHT_PIN, HIGH);
            publishDeviceState();
        }
    }
    if (lightSchedule.off_hour != -1 && currentHour == lightSchedule.off_hour && currentMinute == lightSchedule.off_minute) {
        if (lightState) {
            Serial.println("SCHEDULE: Turning light OFF");
            lightState = false;
            digitalWrite(LIGHT_PIN, LOW);
            publishDeviceState();
        }
    }

    // --- Kiểm tra lịch của quạt ---
    if (fanSchedule.on_hour != -1 && currentHour == fanSchedule.on_hour && currentMinute == fanSchedule.on_minute) {
        if (!fanState) {
            Serial.println("SCHEDULE: Turning fan ON");
            autoModeEnabled = false; // Hẹn giờ ưu tiên hơn tự động
            fanState = true;
            controlMotor(true);
            publishDeviceState();
        }
    }
    if (fanSchedule.off_hour != -1 && currentHour == fanSchedule.off_hour && currentMinute == fanSchedule.off_minute) {
        if (fanState) {
            Serial.println("SCHEDULE: Turning fan OFF");
            fanState = false;
            controlMotor(false);
            publishDeviceState();
        }
    }
}


// =============================================================================
// CÁC HÀM ĐÃ CÓ (GIỮ NGUYÊN HOẶC CẬP NHẬT)
// =============================================================================

void checkAutomation(float temperature) {
    if (!autoModeEnabled) return;
    if (temperature > 30.0 && !fanState) {
        Serial.println("AUTOMATION: Temperature high, turning fan ON.");
        fanState = true; controlMotor(true); publishDeviceState();
    } else if (temperature < 28.0 && fanState) {
        Serial.println("AUTOMATION: Temperature normal, turning fan OFF.");
        fanState = false; controlMotor(false); publishDeviceState();
    }
}

void controlMotor(bool turnOn) {
    if (turnOn) {
        Serial.println("Turning motor ON (Forward, Full Speed)");
        digitalWrite(MOTOR_IN1_PIN, HIGH);
        digitalWrite(MOTOR_IN2_PIN, LOW);
        analogWrite(MOTOR_ENA_PIN, 255); 
    } else {
        Serial.println("Turning motor OFF");
        digitalWrite(MOTOR_IN1_PIN, LOW);
        digitalWrite(MOTOR_IN2_PIN, LOW);
        analogWrite(MOTOR_ENA_PIN, 0);
    }
}

void onMqttMessage(char* topic, byte* payload, unsigned int length) {
  String topicStr = String(topic);
  String message;
  for (int i = 0; i < length; i++) { message += (char)payload[i]; }
  
  Serial.printf("Received [%s]: %s\n", topic, message.c_str());

  if (topicStr == topicDeviceCmd) {
    handleDeviceCommand(message);
  } 
  else if (topicStr == topicScheduleSet) {
    JsonDocument doc;
    if (deserializeJson(doc, message) == DeserializationError::Ok) {
        const char* device = doc["device"];
        if (device) {
             saveSchedule(device, doc.as<JsonObject>());
        }
    }
  }
}

void connectMQTT() {
  if (WiFi.status() != WL_CONNECTED) return;
  Serial.printf("Connecting to MQTT broker: %s:%d\n", MQTT_HOST, MQTT_PORT);
  String lwt = "{\"online\":false}";
  if (mqttClient.connect(DEVICE_ID, MQTT_USERNAME, MQTT_PASSWORD, topicSysOnline.c_str(), 1, true, lwt.c_str())) {
    Serial.println("MQTT connected successfully!");
    mqttClient.subscribe(topicDeviceCmd.c_str(), 1);
    
    mqttClient.subscribe(topicScheduleSet.c_str(), 1);
    Serial.printf("Subscribed to: %s and %s\n", topicDeviceCmd.c_str(), topicScheduleSet.c_str());
    
    publishOnlineStatus(true);
    publishDeviceState();
    deviceOnline = true;
  } else {
    Serial.printf("MQTT connection failed! State: %d\n", mqttClient.state());
    deviceOnline = false;
  }
}

void handleDeviceCommand(String message) {
    unsigned long currentTime = millis();
    if (currentTime - lastCommandTime < COMMAND_DEBOUNCE_DELAY) {
        Serial.println("Command ignored (debounce)");
        return;
    }
    lastCommandTime = currentTime;

    JsonDocument doc;
    if (deserializeJson(doc, message) != DeserializationError::Ok) {
        Serial.println("JSON parse error");
        return;
    }
    
    bool stateChanged = false;

    if (doc.containsKey("light")) {
        if (String(doc["light"]) == "toggle") {
        lightState = !lightState;
        digitalWrite(LIGHT_PIN, lightState);
        Serial.printf("MANUAL: Light turned %s\n", lightState ? "ON" : "OFF");
        stateChanged = true;
        }
    }
    
    if (doc.containsKey("fan")) {
        if (String(doc["fan"]) == "toggle") {
        if (autoModeEnabled) {
            autoModeEnabled = false;
            Serial.println("MANUAL: User control detected. Auto mode DISABLED.");
        }
        
        fanState = !fanState;
        controlMotor(fanState);
        Serial.printf("MANUAL: Fan turned %s\n", fanState ? "ON" : "OFF");
        stateChanged = true;
        }
    }
    
    if (doc.containsKey("auto_mode")) {
        if (String(doc["auto_mode"]) == "toggle") {
            autoModeEnabled = !autoModeEnabled;
            Serial.printf("SYSTEM: Automation mode is now %s\n", autoModeEnabled ? "ENABLED" : "DISABLED");
            publishDeviceState();
        }
    }
    
    if (stateChanged) {
        publishDeviceState();
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
  
  checkAutomation(temperature);

  JsonDocument doc;
  doc["ts"] = time(nullptr);
  doc["temp_c"] = round(temperature * 10) / 10.0;
  doc["hum_pct"] = round(humidity * 10) / 10.0;
  
  String payload;
  serializeJson(doc, payload);
  mqttClient.publish(topicSensorState.c_str(), payload.c_str(), false);
}

void publishDeviceState() {
  if (!mqttClient.connected()) return;
  JsonDocument doc;
  doc["ts"] = time(nullptr);
  doc["light"] = lightState ? "on" : "off";
  doc["fan"] = fanState ? "on" : "off";
  doc["rssi"] = WiFi.RSSI();
  doc["fw"] = FIRMWARE_VERSION;
  doc["auto_mode"] = autoModeEnabled;
  
  String payload;
  serializeJson(doc, payload);
  mqttClient.publish(topicDeviceState.c_str(), payload.c_str(), true);
}

void initGPIO() {
  pinMode(LIGHT_PIN, OUTPUT);
  pinMode(STATUS_LED_PIN, OUTPUT);
  pinMode(MOTOR_IN1_PIN, OUTPUT);
  pinMode(MOTOR_IN2_PIN, OUTPUT);
  digitalWrite(LIGHT_PIN, LOW);
  digitalWrite(STATUS_LED_PIN, LOW);
  digitalWrite(MOTOR_IN1_PIN, LOW);
  digitalWrite(MOTOR_IN2_PIN, LOW);
}

void initTopics() {
  topicSensorState = String(TOPIC_NS) + "/sensor/state";
  topicDeviceState = String(TOPIC_NS) + "/device/state";
  topicDeviceCmd = String(TOPIC_NS) + "/device/cmd";
  topicSysOnline = String(TOPIC_NS) + "/sys/online";
  topicScheduleSet = String(TOPIC_NS) + "/schedule/set";
}

void initWiFi() {
  Serial.printf("Connecting to WiFi: %s\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}
void initNTP() {
  if (WiFi.status() != WL_CONNECTED) return;
  configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET_SEC, NTP_SERVER);
}
void initMQTT() {
  mqttClient.setServer(MQTT_HOST, MQTT_PORT);
  mqttClient.setCallback(onMqttMessage);
  connectMQTT();
}
void checkWiFi(unsigned long currentTime) {
  if (WiFi.status() != WL_CONNECTED && currentTime - lastWifiCheck > WIFI_RECONNECT_INTERVAL) {
    WiFi.reconnect();
    lastWifiCheck = currentTime;
  }
}
void checkMQTT(unsigned long currentTime) {
  if (WiFi.status() == WL_CONNECTED && !mqttClient.connected() && currentTime - lastMqttCheck > MQTT_RECONNECT_INTERVAL) {
    connectMQTT();
    lastMqttCheck = currentTime;
  }
}
void publishOnlineStatus(bool online) {
  if (!mqttClient.connected()) return;
  JsonDocument doc;
  doc["online"] = online;
  String payload;
  serializeJson(doc, payload);
  mqttClient.publish(topicSysOnline.c_str(), payload.c_str(), true);
}
void updateStatusLED() {
  if (mqttClient.connected()) {
    digitalWrite(STATUS_LED_PIN, HIGH);
  } else if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(STATUS_LED_PIN, millis() % 500 < 250);
  } else {
    digitalWrite(STATUS_LED_PIN, millis() % 2000 < 1000);
  }
}

