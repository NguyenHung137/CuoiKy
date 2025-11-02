import 'dart:convert';
import 'dart:html' as html;
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
  // Simulated states for demo
  bool _brokerConnected = false;
  bool _deviceOnline = false;
  String _lightState = 'off';
  String _fanState = 'off';
  String _rssi = '--';
  String _firmware = 'v1.0.0';
  String _lastUpdate = '--';

  @override
  void initState() {
    super.initState();
    _simulateConnection();
  }

  void _simulateConnection() {
    // Simulate connection after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _brokerConnected = true;
          _deviceOnline = true;
          _rssi = '-65 dBm';
          _lastUpdate = DateTime.now().toString().substring(11, 19);
        });
      }
    });
  }

  void _toggleDevice(String device) {
    setState(() {
      if (device == 'light') {
        _lightState = _lightState == 'on' ? 'off' : 'on';
      } else if (device == 'fan') {
        _fanState = _fanState == 'on' ? 'off' : 'on';
      }
      _lastUpdate = DateTime.now().toString().substring(11, 19);
    });
    
    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${device.toUpperCase()} turned ${device == 'light' ? _lightState : _fanState}'),
        duration: const Duration(seconds: 1),
      ),
    );
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
        child: SafeArea(
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
                        status: _brokerConnected ? 'Connected' : 'Connecting...',
                        color: _brokerConnected ? Colors.green : Colors.orange,
                        icon: _brokerConnected ? Icons.wifi : Icons.wifi_off,
                        gradient: _brokerConnected 
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.orange.shade400, Colors.orange.shade600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatusCard(
                        title: 'ESP32 Device',
                        status: _deviceOnline ? 'Online' : 'Offline',
                        color: _deviceOnline ? Colors.blue : Colors.grey,
                        icon: _deviceOnline ? Icons.developer_board : Icons.developer_board_off,
                        gradient: _deviceOnline 
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
                        value: _lightState == 'on',
                        onChanged: _brokerConnected && _deviceOnline
                            ? (value) => _toggleDevice('light')
                            : null,
                        subtitle: 'Status: ${_lightState.toUpperCase()}',
                        activeGradient: [Colors.orange.shade400, Colors.orange.shade600],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      _ControlCard(
                        title: '🌀 Smart Fan',
                        icon: Icons.air_rounded,
                        value: _fanState == 'on',
                        onChanged: _brokerConnected && _deviceOnline
                            ? (value) => _toggleDevice('fan')
                            : null,
                        subtitle: 'Status: ${_fanState.toUpperCase()}',
                        activeGradient: [Colors.cyan.shade400, Colors.cyan.shade600],
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
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.info_rounded, color: Colors.purple.shade700, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Device Information',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                
                // Connection info
                if (!_brokerConnected)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connecting to MQTT broker...',
                          style: TextStyle(color: Colors.orange.shade700),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
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
      shadowColor: value ? activeGradient.first.withOpacity(0.3) : Colors.black.withOpacity(0.1),
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
                  color: value ? Colors.white.withOpacity(0.2) : Colors.grey.shade300,
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