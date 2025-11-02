import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Controller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.black.withOpacity(0.1),
        ),
      ),
      home: const IoTControllerPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class IoTControllerPage extends StatefulWidget {
  const IoTControllerPage({super.key});

  @override
  State<IoTControllerPage> createState() => _IoTControllerPageState();
}

class _IoTControllerPageState extends State<IoTControllerPage> {
  // MQTT connection states
  bool _brokerConnected = false;
  bool _deviceOnline = false;
  String _lightState = 'off';
  String _fanState = 'off';
  String _rssi = '--';
  String _firmware = '--';
  String _lastUpdate = '--';
  bool _autoModeEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeMQTT();
  }

  void _initializeMQTT() {
    // Load MQTT.js library and initialize connection
    html.document.head!.append(html.ScriptElement()
      ..src = 'https://unpkg.com/mqtt/dist/mqtt.min.js'
      ..onLoad.listen((_) => _connectMQTT()));
  }

  void _connectMQTT() {
    // Cấu hình đúng cho Broker nội bộ
    const protocol = 'ws';
    const host = '192.168.1.216';
    const port = 9001;
    const username = 'user1';
    const password = 'pass1';
    const topicNamespace = 'lab/room1';

    final brokerUrl = '$protocol://$host:$port';

    // Create MQTT client using JavaScript
    js.context.callMethod('eval', [
      '''
      const options = {
        clientId: 'flutter_web_' + Math.random().toString(16).substr(2, 8),
        username: '$username',
        password: '$password'
      };

      console.log('Attempting to connect to $brokerUrl');
      window.flutterMqttClient = mqtt.connect('$brokerUrl', options);

      window.flutterMqttClient.on('connect', function() {
        console.log('Flutter MQTT connected via JS');
        window.dispatchEvent(new CustomEvent('mqtt_connected'));

        const topics = ['$topicNamespace/device/state', '$topicNamespace/sys/online'];
        window.flutterMqttClient.subscribe(topics, function (err) {
          if (!err) {
            console.log('Subscribed to:', topics.join(', '));
          } else {
            console.error('Subscription error:', err);
          }
        });
      });

      window.flutterMqttClient.on('message', function(topic, message) {
        const payload = message.toString();
        console.log('JS received message on', topic, 'with payload', payload);
        window.dispatchEvent(new CustomEvent('mqtt_message', {
          detail: { topic: topic, payload: payload }
        }));
      });

      window.flutterMqttClient.on('error', function(error) {
        console.error('JS MQTT Error:', error);
        window.dispatchEvent(new CustomEvent('mqtt_error'));
      });

      // Hàm gửi lệnh bật/tắt
      window.sendMqttCommand = function(device, action) {
        const topic = '$topicNamespace/device/cmd';
        const command = {};
        command[device] = action;
        const payload = JSON.stringify(command);

        console.log('JS Publishing command to', topic, 'with payload', payload);
        window.flutterMqttClient.publish(topic, payload);
      };

      // *** HÀM MỚI ĐỂ GỬI LỊCH TRÌNH ***
      window.sendMqttSchedule = function(payload) {
        const topic = '$topicNamespace/schedule/set';
        console.log('JS Publishing schedule to', topic, 'with payload', payload);
        window.flutterMqttClient.publish(topic, payload);
      }
    '''
    ]);

    // Phần lắng nghe sự kiện giữ nguyên
    html.window.addEventListener('mqtt_connected', (event) {
      if (mounted) setState(() => _brokerConnected = true);
    });
    html.window.addEventListener('mqtt_message', (event) {
      final detail = (event as html.CustomEvent).detail;
      _handleMqttMessage(detail['topic'], detail['payload']);
    });
    html.window.addEventListener('mqtt_error', (event) {
      if (mounted) {
        setState(() {
          _brokerConnected = false;
          _deviceOnline = false;
        });
      }
    });
  }

  void _handleMqttMessage(String topic, String payload) {
    if (!mounted) return;
    try {
      final data = jsonDecode(payload);
      if (topic.endsWith('/device/state')) {
        setState(() {
          _lightState = data['light'] ?? 'unknown';
          _fanState = data['fan'] ?? 'unknown';
          _rssi = '${data['rssi'] ?? 0} dBm';
          _firmware = data['fw'] ?? '--';
          _autoModeEnabled =
              data['auto_mode'] ?? true; // Cập nhật trạng thái auto mode
          _lastUpdate = DateTime.now().toString().substring(11, 19);
        });
      } else if (topic.endsWith('/sys/online')) {
        setState(() => _deviceOnline = data['online'] ?? false);
      }
    } catch (e) {
      print('Error parsing MQTT message: $e');
    }
  }

  void _toggleDevice(String device) {
    if (!_brokerConnected || !_deviceOnline) return;
    js.context.callMethod('sendMqttCommand', [device, 'toggle']);
  }

  // *** HÀM MỚI ĐỂ GỬI LỊCH TRÌNH QUA JAVASCRIPT ***
  void _publishSchedule(String device, TimeOfDay onTime, TimeOfDay offTime) {
    final payload = jsonEncode({
      'device': device,
      'on_hour': onTime.hour,
      'on_minute': onTime.minute,
      'off_hour': offTime.hour,
      'off_minute': offTime.minute,
    });
    js.context.callMethod('sendMqttSchedule', [payload]);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Schedule for $device saved!'),
          backgroundColor: Colors.green),
    );
  }

  // *** HÀM MỚI ĐỂ HIỂN THỊ HỘP THOẠI HẸN GIỜ ***
  Future<void> _showScheduleDialog(String device) async {
    TimeOfDay onTime = TimeOfDay.now();
    TimeOfDay offTime = TimeOfDay.now();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                  'Set Schedule for ${device == 'light' ? 'Light' : 'Fan'}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.wb_sunny_outlined),
                    title: const Text('Turn ON Time'),
                    trailing: Text(onTime.format(context)),
                    onTap: () async {
                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime: onTime,
                      );
                      if (selectedTime != null) {
                        setDialogState(() => onTime = selectedTime);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.nightlight_round),
                    title: const Text('Turn OFF Time'),
                    trailing: Text(offTime.format(context)),
                    onTap: () async {
                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime: offTime,
                      );
                      if (selectedTime != null) {
                        setDialogState(() => offTime = selectedTime);
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    _publishSchedule(device, onTime, offTime);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('🏠 IoT Device Controller'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.purple.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _StatusCard(
                            title: 'MQTT Broker',
                            status: _brokerConnected
                                ? 'Connected'
                                : 'Connecting...',
                            color:
                                _brokerConnected ? Colors.green : Colors.orange,
                            icon:
                                _brokerConnected ? Icons.wifi : Icons.wifi_off,
                            gradient: _brokerConnected
                                ? [Colors.green.shade400, Colors.green.shade600]
                                : [
                                    Colors.orange.shade400,
                                    Colors.orange.shade600
                                  ])),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _StatusCard(
                            title: 'ESP32 Device',
                            status: _deviceOnline ? 'Online' : 'Offline',
                            color: _deviceOnline ? Colors.blue : Colors.grey,
                            icon: _deviceOnline
                                ? Icons.developer_board
                                : Icons.developer_board_off,
                            gradient: _deviceOnline
                                ? [Colors.blue.shade400, Colors.blue.shade600]
                                : [
                                    Colors.grey.shade400,
                                    Colors.grey.shade600
                                  ])),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    children: [
                      _ControlCard(
                        title: '💡 Smart Light',
                        icon: Icons.lightbulb_rounded,
                        value: _lightState == 'on',
                        onChanged: _brokerConnected && _deviceOnline
                            ? (value) => _toggleDevice('light')
                            : null,
                        onSchedulePressed: _brokerConnected && _deviceOnline
                            ? () => _showScheduleDialog('light')
                            : null,
                        subtitle: 'Status: ${_lightState.toUpperCase()}',
                        activeGradient: [
                          Colors.orange.shade400,
                          Colors.orange.shade600
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ControlCard(
                        title: '🌀 Smart Fan',
                        icon: Icons.air_rounded,
                        value: _fanState == 'on',
                        onChanged: _brokerConnected && _deviceOnline
                            ? (value) => _toggleDevice('fan')
                            : null,
                        onSchedulePressed: _brokerConnected && _deviceOnline
                            ? () => _showScheduleDialog('fan')
                            : null,
                        subtitle: 'Status: ${_fanState.toUpperCase()}',
                        activeGradient: [
                          Colors.cyan.shade400,
                          Colors.cyan.shade600
                        ],
                      ),
                      const SizedBox(height: 16),
                      _ControlCard(
                        title: '🤖 Auto Mode',
                        icon: Icons.thermostat_auto_rounded,
                        value: _autoModeEnabled,
                        onChanged: _brokerConnected && _deviceOnline
                            ? (value) => _toggleDevice('auto_mode')
                            : null,
                        onSchedulePressed: null,
                        subtitle:
                            'Fan Automation: ${_autoModeEnabled ? "ENABLED" : "DISABLED"}',
                        activeGradient: [
                          Colors.teal.shade400,
                          Colors.teal.shade600
                        ],
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 8,
                        shadowColor: Colors.purple.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
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
                                        borderRadius: BorderRadius.circular(8),
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
                                _InfoRow('📡 WiFi Signal', _rssi),
                                _InfoRow('💿 Firmware', _firmware),
                                _InfoRow('⏰ Last Update', _lastUpdate),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                  fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value,
                style: TextStyle(
                    color: Colors.purple.shade800,
                    fontWeight: FontWeight.w500,
                    fontSize: 13)),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: 100,
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
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                Text(
                  status,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
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
  final VoidCallback? onSchedulePressed;
  final String subtitle;
  final List<Color> activeGradient;

  const _ControlCard(
      {required this.title,
      required this.icon,
      required this.value,
      required this.onChanged,
      this.onSchedulePressed,
      required this.subtitle,
      required this.activeGradient,
      super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: value ? 8 : 4,
      shadowColor: value
          ? activeGradient.first.withOpacity(0.3)
          : Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: value
              ? LinearGradient(colors: activeGradient)
              : LinearGradient(colors: [Colors.white, Colors.grey.shade100]),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: value
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: value ? Colors.white : Colors.grey.shade700,
                    size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                value ? Colors.white : Colors.grey.shade800)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                value ? Colors.white70 : Colors.grey.shade600)),
                  ],
                ),
              ),
              if (onSchedulePressed != null)
                IconButton(
                  icon: Icon(Icons.timer_outlined,
                      color: value ? Colors.white70 : Colors.grey.shade600),
                  onPressed: onSchedulePressed,
                  tooltip: 'Set Schedule',
                ),
              Transform.scale(
                scale: 1.1,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.white.withOpacity(0.3),
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
