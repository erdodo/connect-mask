import 'package:flutter/material.dart';
import '../models/device_mode.dart';
import '../services/settings_service.dart';
import 'home_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final SettingsService _settingsService = SettingsService();

  DeviceMode? _selectedMode;
  ConnectionType? _selectedConnection;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    await _settingsService.init();
    final savedMode = _settingsService.getDeviceMode();
    final savedConnection = _settingsService.getConnectionType();

    setState(() {
      _selectedMode = savedMode;
      _selectedConnection = savedConnection;
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selectedMode == null || _selectedConnection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm seçenekleri belirleyin')),
      );
      return;
    }

    await _settingsService.setDeviceMode(_selectedMode!);
    await _settingsService.setConnectionType(_selectedConnection!);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          deviceMode: _selectedMode!,
          connectionType: _selectedConnection!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('GPS Client Kurulum'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hoş geldiniz kartı
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_searching,
                      size: 64,
                      color: Colors.green[700],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'GPS Paylaşım Sistemi',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bu cihazın rolünü belirleyin',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Cihaz Modu Seçimi
            const Text(
              '1. Cihaz Modu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...DeviceMode.values.map((mode) {
              return Card(
                elevation: _selectedMode == mode ? 4 : 2,
                color: _selectedMode == mode ? Colors.green[50] : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _selectedMode == mode
                        ? Colors.green[700]!
                        : Colors.grey[300]!,
                    width: _selectedMode == mode ? 2 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMode = mode;
                      _selectedConnection = null; // Reset connection
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          mode == DeviceMode.server
                              ? Icons.cloud_upload
                              : Icons.cloud_download,
                          size: 40,
                          color: _selectedMode == mode
                              ? Colors.green[700]
                              : Colors.grey[600],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedMode == mode
                                      ? Colors.green[700]
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mode.description,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedMode == mode)
                          Icon(Icons.check_circle, color: Colors.green[700]),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),

            if (_selectedMode != null) ...[
              const SizedBox(height: 24),

              // Bağlantı Tipi Seçimi
              const Text(
                '2. Bağlantı Tipi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              ...ConnectionType.values.map((type) {
                return Card(
                  elevation: _selectedConnection == type ? 4 : 2,
                  color: _selectedConnection == type ? Colors.blue[50] : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectedConnection == type
                          ? Colors.blue[700]!
                          : Colors.grey[300]!,
                      width: _selectedConnection == type ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedConnection = type;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            type == ConnectionType.api
                                ? Icons.wifi
                                : Icons.bluetooth,
                            size: 40,
                            color: _selectedConnection == type
                                ? Colors.blue[700]
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _selectedConnection == type
                                        ? Colors.blue[700]
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  type.description,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedConnection == type)
                            Icon(Icons.check_circle, color: Colors.blue[700]),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],

            const SizedBox(height: 32),

            // Devam Et Butonu
            if (_selectedMode != null && _selectedConnection != null)
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 28),
                  label: const Text(
                    'Devam Et',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
