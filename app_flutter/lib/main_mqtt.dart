import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MqttController(),
      child: MaterialApp(
        title: 'IoT Controller',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Inter', // Modern font similar to web dashboard
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            shadowColor: Colors.black.withOpacity(0.1),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black87,
            titleTextStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        home: const IoTControllerPage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class IoTControllerPage extends StatefulWidget {
  const IoTControllerPage({super.key});

  @override
  State<IoTControllerPage> createState() => _IoTControllerPageState();
}

class _IoTControllerPageState extends State<IoTControllerPage> {
  @override
  void initState() {
    super.initState();
    // Auto-connect when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MqttController>().connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('🏠 IoT Device Controller'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade400.withOpacity(0.8),
                Colors.purple.shade400.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50,
              Colors.purple.shade50,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Consumer<MqttController>(
          builder: (context, controller, child) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Status Cards with enhanced design
                    Row(
                      children: [
                        Expanded(
                          child: _StatusCard(
                            title: 'MQTT Broker',
                            status: controller.brokerConnected
                                ? 'Connected'
                                : 'Disconnected',
                            color: controller.brokerConnected
                                ? Colors.green
                                : Colors.red,
                            icon: controller.brokerConnected
                                ? Icons.wifi
                                : Icons.wifi_off,
                            gradient: controller.brokerConnected
                                ? [Colors.green.shade400, Colors.green.shade600]
                                : [Colors.red.shade400, Colors.red.shade600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatusCard(
                            title: 'ESP32 Device',
                            status:
                                controller.deviceOnline ? 'Online' : 'Offline',
                            color: controller.deviceOnline
                                ? Colors.blue
                                : Colors.grey,
                            icon: controller.deviceOnline
                                ? Icons.developer_board
                                : Icons.developer_board_off,
                            gradient: controller.deviceOnline
                                ? [Colors.blue.shade400, Colors.blue.shade600]
                                : [Colors.grey.shade400, Colors.grey.shade600],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Control Cards with modern design
                    Expanded(
                      child: Column(
                        children: [
                          _ControlCard(
                            title: '💡 Smart Light',
                            icon: Icons.lightbulb_rounded,
                            value: controller.lightState == 'on',
                            onChanged: controller.brokerConnected &&
                                    controller.deviceOnline
                                ? (value) => controller.toggleDevice('light')
                                : null,
                            subtitle:
                                'Status: ${controller.lightState.toUpperCase()}',
                            activeGradient: [
                              Colors.orange.shade400,
                              Colors.orange.shade600
                            ],
                          ),

                          const SizedBox(height: 16),

                          _ControlCard(
                            title: '🌀 Smart Fan',
                            icon: Icons.air_rounded,
                            value: controller.fanState == 'on',
                            onChanged: controller.brokerConnected &&
                                    controller.deviceOnline
                                ? (value) => controller.toggleDevice('fan')
                                : null,
                            subtitle:
                                'Status: ${controller.fanState.toUpperCase()}',
                            activeGradient: [
                              Colors.cyan.shade400,
                              Colors.cyan.shade600
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Enhanced Device Info Card
                          Card(
                            elevation: 8,
                            shadowColor: Colors.purple.withOpacity(0.3),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple.shade50,
                                    Colors.blue.shade50,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.info_rounded,
                                              color: Colors.purple.shade700,
                                              size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Device Information',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.purple.shade800,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _InfoRow('📡 WiFi Signal',
                                        '${controller.rssi} dBm'),
                                    _InfoRow(
                                        '💿 Firmware', controller.firmware),
                                    _InfoRow(
                                        '⏰ Last Update', controller.lastUpdate),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Enhanced Reconnect Button
                    if (!controller.brokerConnected)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade600,
                                Colors.purple.shade600
                              ],
                            ),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: controller.isConnecting
                                ? null
                                : controller.connect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            icon: controller.isConnecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded,
                                    color: Colors.white),
                            label: Text(
                              controller.isConnecting
                                  ? 'Connecting...'
                                  : 'Reconnect to Broker',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _InfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.purple.shade700,
              fontSize: 14,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: Colors.purple.shade800,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final Color color;
  final IconData icon;
  final List<Color> gradient;

  const _StatusCard({
    required this.title,
    required this.status,
    required this.color,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shadowColor: color.withOpacity(0.3),
      child: Container(
        height: 100, // Giữ nguyên chiều cao
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          // SỬA LỖI: Dùng FittedBox để nội dung tự co giãn
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 4), // Giảm khoảng cách một chút
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String subtitle;
  final List<Color> activeGradient;

  const _ControlCard({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.subtitle,
    required this.activeGradient,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: value ? 8 : 4,
      shadowColor: value
          ? activeGradient.first.withOpacity(0.3)
          : Colors.black.withOpacity(0.1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: value
              ? LinearGradient(
                  colors: activeGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade100, Colors.grey.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: value
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: value ? Colors.white : Colors.grey.shade600,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: value ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: value ? Colors.white70 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Transform.scale(
                scale: 1.2,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white.withOpacity(0.3),
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MqttController extends ChangeNotifier {
  // Configuration - SỬA LẠI ĐỂ KẾT NỐI VÀO BROKER NỘI BỘ
  static const String mqttHost = '10.0.2.2'; // <--- SỬA 1: Dùng IP của bạn
  static const int mqttPort = 1883;
  static const String mqttUsername = 'user1'; // <--- SỬA 2: Thêm username
  static const String mqttPassword = 'pass1'; // <--- SỬA 3: Thêm password
  static const String topicNamespace =
      'lab/room1'; // <--- SỬA 4: Dùng đúng topic

  // MQTT Client
  late MqttServerClient _client;

  // Connection states
  bool _brokerConnected = false;
  bool _deviceOnline = false;
  bool _isConnecting = false;

  // Device states
  String _lightState = 'off';
  String _fanState = 'off';
  String _rssi = '--';
  String _firmware = '--';
  String _lastUpdate = '--';

  // Topics
  late String _deviceCmdTopic;
  late String _deviceStateTopic;
  late String _sysOnlineTopic;

  // Getters
  bool get brokerConnected => _brokerConnected;
  bool get deviceOnline => _deviceOnline;
  bool get isConnecting => _isConnecting;
  String get lightState => _lightState;
  String get fanState => _fanState;
  String get rssi => _rssi;
  String get firmware => _firmware;
  String get lastUpdate => _lastUpdate;

  MqttController() {
    _initializeTopics();
    _initializeClient();
  }

  void _initializeTopics() {
    _deviceCmdTopic = '$topicNamespace/device/cmd';
    _deviceStateTopic = '$topicNamespace/device/state';
    _sysOnlineTopic = '$topicNamespace/sys/online';
  }

  void _initializeClient() {
    final clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient.withPort(mqttHost, clientId, mqttPort);

    _client.logging(on: true);
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onUnsubscribed = _onUnsubscribed;
    _client.onSubscribed = _onSubscribed;
    _client.onSubscribeFail = _onSubscribeFail;
    _client.pongCallback = _pong;
    _client.keepAlivePeriod = 30;
    _client.connectTimeoutPeriod = 5000;
    _client.autoReconnect = true;
  }

  Future<void> connect() async {
    if (_isConnecting) return;

    _isConnecting = true;
    notifyListeners();

    try {
      print('Connecting to MQTT broker at $mqttHost:$mqttPort');

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_client.clientIdentifier)
          .withWillTopic('$topicNamespace/app/online')
          .withWillMessage('{"online":false}')
          .withWillRetain()
          .startClean()
          .withWillQos(MqttQos.atLeastOnce);

      // Set credentials if provided
      if (mqttUsername.isNotEmpty && mqttPassword.isNotEmpty) {
        connMessage.authenticateAs(mqttUsername, mqttPassword);
      }

      _client.connectionMessage = connMessage;

      await _client.connect();
    } catch (e) {
      print('Connection failed: $e');
      _onConnectionFailed();
    }
  }

  void _onConnected() {
    print('Connected to MQTT broker');
    _brokerConnected = true;
    _isConnecting = false;

    // Subscribe to topics
    _client.subscribe(_deviceStateTopic, MqttQos.atLeastOnce);
    _client.subscribe(_sysOnlineTopic, MqttQos.atLeastOnce);

    // Listen for messages
    _client.updates!.listen(_onMessage);

    notifyListeners();
  }

  void _onDisconnected() {
    print('Disconnected from MQTT broker');
    _brokerConnected = false;
    _deviceOnline = false;
    _isConnecting = false;
    notifyListeners();
  }

  void _onConnectionFailed() {
    _brokerConnected = false;
    _deviceOnline = false;
    _isConnecting = false;
    notifyListeners();
  }

  void _onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  void _onSubscribeFail(String topic) {
    print('Failed to subscribe to $topic');
  }

  void _onUnsubscribed(String? topic) {
    print('Unsubscribed from $topic');
  }

  void _pong() {
    print('Ping response client callback invoked');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      final topic = message.topic;
      final payload = MqttPublishPayload.bytesToStringAsString(
        (message.payload as MqttPublishMessage).payload.message,
      );

      print('Received message on $topic: $payload');
      _handleMessage(topic, payload);
    }
  }

  void _handleMessage(String topic, String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;

      if (topic == _deviceStateTopic) {
        _handleDeviceState(data);
      } else if (topic == _sysOnlineTopic) {
        _handleOnlineStatus(data);
      }

      _updateLastUpdate();
      notifyListeners();
    } catch (e) {
      print('Error parsing message: $e');
    }
  }

  void _handleDeviceState(Map<String, dynamic> data) {
    if (data.containsKey('light')) {
      _lightState = data['light'] as String;
    }
    if (data.containsKey('fan')) {
      _fanState = data['fan'] as String;
    }
    if (data.containsKey('rssi')) {
      _rssi = data['rssi'].toString();
    }
    if (data.containsKey('fw')) {
      _firmware = data['fw'] as String;
    }
  }

  void _handleOnlineStatus(Map<String, dynamic> data) {
    if (data.containsKey('online')) {
      _deviceOnline = data['online'] as bool;
    }
  }

  void _updateLastUpdate() {
    final now = DateTime.now();
    _lastUpdate = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  void toggleDevice(String device) {
    if (!_brokerConnected) {
      print('Not connected to broker');
      return;
    }

    final command = jsonEncode({device: 'toggle'});
    print('Sending command: $command to $_deviceCmdTopic');

    final builder = MqttClientPayloadBuilder();
    builder.addString(command);

    _client.publishMessage(
      _deviceCmdTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }
}
