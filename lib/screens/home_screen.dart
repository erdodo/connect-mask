import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../models/gps_data.dart';
import '../models/device_mode.dart';
import '../services/gps_service.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';
import 'qr_connection_screen.dart';

class HomeScreen extends StatefulWidget {
  final DeviceMode deviceMode;
  final ConnectionType connectionType;

  const HomeScreen({
    super.key,
    required this.deviceMode,
    required this.connectionType,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GpsService _gpsService = GpsService();
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _ipController = TextEditingController();

  GpsData? _currentGpsData;
  StreamSubscription<GpsData>? _gpsSubscription;

  // Client mode için tarama durumları
  bool _isScanning = false;
  List<String> _discoveredServers = [];
  String? _scanningStatus;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _settingsService.init();

    // GPS stream'i dinle
    _gpsSubscription = _gpsService.gpsStream.listen((data) {
      setState(() {
        _currentGpsData = data;
      });
    });

    // İlk açılışta pil optimizasyonu uyarısı göster (sadece client modda)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isFirstLaunch = _settingsService.isFirstLaunch();
      if (isFirstLaunch && widget.deviceMode == DeviceMode.client) {
        await _settingsService.setFirstLaunch(false);
        _showBatteryOptimizationDialog();
      }
    });

    setState(() {});
  }

  void _toggleService() async {
    if (_gpsService.isRunning) {
      await _gpsService.stop();
      setState(() {});
      _showSnackBar('Servis durduruldu', Colors.orange);
    } else {
      // Client modunda bağlantı kurma akışı
      if (widget.deviceMode == DeviceMode.client) {
        // İzin kontrolü
        final hasPermission = await _gpsService.checkMockPermission();
        if (!hasPermission) {
          _showPermissionDialog();
          return;
        }

        // WiFi modunda server seçimi veya tarama
        _showWifiConnectionDialog();
        return;
      }

      // Server modunda direkt başlat
      final started = await _gpsService.start(
        mode: widget.deviceMode,
        connection: widget.connectionType,
      );

      setState(() {});

      if (started) {
        _showSnackBar('Servis başlatıldı', Colors.green);
      } else {
        _showSnackBar('Servis başlatılamadı', Colors.red);
      }
    }
  }

  // WiFi taraması ve manuel IP girişi için dialog
  void _showWifiConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.wifi_find, color: Colors.blue),
                SizedBox(width: 8),
                Text('Server Bağlantısı'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Manuel IP girişi
                  TextField(
                    controller: _ipController,
                    decoration: InputDecoration(
                      labelText: 'Server IP Adresi',
                      hintText: '192.168.1.100',
                      prefixIcon: const Icon(Icons.computer),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.link),
                        onPressed: () async {
                          final ip = _ipController.text.trim();
                          if (ip.isNotEmpty) {
                            Navigator.pop(context);
                            await _connectToServer(ip);
                          }
                        },
                        tooltip: 'Bağlan',
                      ),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // QR Kod Butonu
                  ElevatedButton.icon(
                    onPressed: () => _openQrConnection(context),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(
                      widget.deviceMode == DeviceMode.client
                          ? 'QR Kod Göster'
                          : 'QR Kod Oku',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Tarama durumu
                  if (_isScanning) ...[
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(
                            _scanningStatus ?? 'Taranıyor...',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bulunan serverlar
                  if (_discoveredServers.isNotEmpty) ...[
                    const Text(
                      'Bulunan Serverlar:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_discoveredServers.map(
                      (ip) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.dns, color: Colors.blue),
                        title: Text(ip),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          Navigator.pop(context);
                          _connectToServer(ip);
                        },
                        tileColor: Colors.green[50],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )),
                    const SizedBox(height: 8),
                  ],

                  // Tarama butonu
                  ElevatedButton.icon(
                    onPressed: _isScanning
                        ? null
                        : () => _startWifiScan(setDialogState),
                    icon: Icon(
                      _isScanning ? Icons.hourglass_empty : Icons.search,
                    ),
                    label: Text(_isScanning ? 'Taranıyor...' : 'Ağı Tara'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isScanning ? null : () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
            ],
          );
        },
      ),
    );
  }

  // WiFi taramasını başlat
  Future<void> _startWifiScan(StateSetter setDialogState) async {
    setDialogState(() {
      _isScanning = true;
      _discoveredServers.clear();
      _scanningStatus = 'Yerel ağ taranıyor...';
    });

    try {
      // Tüm subnet'leri al
      final subnets = await _getAllSubnets();

      if (subnets.isEmpty) {
        setDialogState(() {
          _isScanning = false;
          _scanningStatus = 'Taranacak ağ bulunamadı';
        });
        return;
      }

      print('🔍 ${subnets.length} subnet taranacak: ${subnets.join(", ")}');

      // Her subnet'i tara
      for (var subnet in subnets) {
        if (!_isScanning) break;

        for (int i = 1; i <= 254; i++) {
          if (!_isScanning) break;

          setDialogState(() {
            _scanningStatus = 'Taranıyor: $subnet$i';
          });

          final ip = '$subnet$i';

          // Port 8765'i kontrol et
          try {
            final socket = await Socket.connect(
              ip,
              8765,
              timeout: const Duration(milliseconds: 150),
            );
            socket.destroy();

            setDialogState(() {
              if (!_discoveredServers.contains(ip)) {
                _discoveredServers.add(ip);
              }
            });
          } catch (_) {
            // Bu IP'de server yok, devam et
          }
        }
      }
    } catch (e) {
      print('WiFi tarama hatası: $e');
    }

    setDialogState(() {
      _isScanning = false;
      _scanningStatus = _discoveredServers.isEmpty
          ? 'Server bulunamadı'
          : '${_discoveredServers.length} server bulundu';
    });
  }

  // Tüm subnet'leri al (WiFi, Hotspot, vb.)
  Future<List<String>> _getAllSubnets() async {
    List<String> subnets = [];

    try {
      final interfaces = await NetworkInterface.list();

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final ip = addr.address;

            // Özel IP aralıklarını kontrol et
            if (ip.startsWith('192.168.') ||
                ip.startsWith('172.') ||
                ip.startsWith('10.')) {
              final parts = ip.split('.');
              if (parts.length == 4) {
                final subnet = '${parts[0]}.${parts[1]}.${parts[2]}.';
                if (!subnets.contains(subnet)) {
                  subnets.add(subnet);
                  print('📡 Subnet bulundu: $subnet');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Subnet alma hatası: $e');
    }

    // Fallback: varsayılan subnet'ler
    if (subnets.isEmpty) {
      subnets.add('192.168.1.'); // Standart WiFi
      subnets.add('192.168.43.'); // Android hotspot
      subnets.add('172.20.10.'); // iOS hotspot
    }

    return subnets;
  }

  // Subnet adresini al (eski metod - geriye dönük uyumluluk için)
  // QR Kod ile bağlantı
  Future<void> _openQrConnection(BuildContext context) async {
    if (widget.deviceMode == DeviceMode.server) {
      // Server mode: QR kodu tara
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => QrConnectionScreen(
            deviceMode: DeviceMode.server,
            onServerFound: (clientIp) async {
              // QR'dan okunan client IP'ye bağlan
              print('📱 Server: Client IP alındı: $clientIp');
              await _connectToServer(clientIp);
            },
          ),
        ),
      );

      // QR ekranından dönüş
      if (result != null) {
        print('✅ Server: Bağlantı başarılı, WiFi dialog kapatılıyor');
        if (mounted) {
          Navigator.pop(context); // WiFi dialog'unu kapat
        }
      }
    } else {
      // Client mode: ÖNCE start() call et, SONRA QR göster
      print('📱 Client: QR Kod Göster - Önce start() çağrılıyor...');

      // Client'ı başlat (WebSocket server açılacak)
      final started = await _gpsService.start(
        mode: widget.deviceMode,
        connection: widget.connectionType,
      );

      if (!started) {
        _showSnackBar('Client başlatılamadı', Colors.red);
        return;
      }

      print('✅ Client: start() tamamlandı, WebSocket server açıldı');
      print('� Client Server IP: ${_gpsService.serverIp}');

      // Şimdi Client'ın IP'sini al (WebSocket server başlatıldığı için serverIp dolu olmalı)
      String? clientIp = _gpsService.serverIp;

      if (clientIp == null || clientIp.isEmpty) {
        _showSnackBar('Client IP alınamadı', Colors.red);
        return;
      }

      print('📱 Client: QR ekranına IP gönderiliyor: $clientIp');

      // QR ekranını göster
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QrConnectionScreen(
            deviceMode: DeviceMode.client,
            clientIp: clientIp,
          ),
        ),
      );

      // QR ekranından dönüş (WiFi dialog'u açık kalsın)
      if (mounted) {
        print('✅ Client: QR ekranından dönüş, Server\'ı bekliyor...');
      }
    }
  }

  // Server'a bağlan
  Future<void> _connectToServer(String serverIp) async {
    setState(() {
      _scanningStatus = 'Bağlanıyor...';
    });

    final started = await _gpsService.start(
      mode: widget.deviceMode,
      connection: widget.connectionType,
      serverIp: serverIp,
    );

    setState(() {
      _scanningStatus = null;
    });

    if (started) {
      _showSnackBar('Server\'a bağlanıldı: $serverIp', Colors.green);
    } else {
      _showSnackBar('Bağlantı başarısız', Colors.red);
    }
  }

  void _navigateToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    setState(() {});
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('İzin Gerekli'),
          ],
        ),
        content: const Text(
          'Bu uygulama için "Sahte Konum" izni gereklidir.\n\n'
          'Lütfen:\n'
          '1. Geliştirici Seçeneklerini açın\n'
          '2. "Sahte konum uygulamasını seç" bölümüne gidin\n'
          '3. "GPS Client" uygulamasını seçin',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _gpsService.openSettings();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Ayarlara Git'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showBatteryOptimizationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.battery_alert, color: Colors.orange),
            SizedBox(width: 8),
            Text('Önemli Ayar'),
          ],
        ),
        content: const Text(
          'Uygulamanın arka planda kesintisiz çalışması için:\n\n'
          '1. Pil optimizasyonunu kapatın\n'
          '2. "İzin ver" veya "Optimize etme"yi seçin\n\n'
          'Bu, mock location servisinin Android tarafından durdurulmasını önler.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Daha Sonra'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _gpsService.requestBatteryExemption();
            },
            icon: const Icon(Icons.battery_charging_full),
            label: const Text('Ayarlara Git'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = _gpsService.isRunning;
    final isServer = widget.deviceMode == DeviceMode.server;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          isServer ? 'Server Modu - GPS Paylaşımı' : 'Client Modu - GPS Alımı',
        ),
        backgroundColor: isServer ? Colors.blue[700] : Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Server modunda kamera butonu
          if (isServer)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => _openQrConnection(context),
              tooltip: 'QR Kod Oku',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
            tooltip: 'Ayarlar',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Bilgisi Kartı
            _buildModeInfoCard(isServer),

            const SizedBox(height: 16),

            // Durum Kartı
            _buildStatusCard(isRunning),

            const SizedBox(height: 16),

            // GPS Bilgi Kartı
            _buildGpsInfoCard(),

            const SizedBox(height: 16),

            // Kontrol Butonları
            _buildControlButtons(isRunning),
          ],
        ),
      ),
    );
  }

  Widget _buildModeInfoCard(bool isServer) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isServer ? Colors.blue[50] : Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              isServer ? Icons.dns : Icons.phone_android,
              size: 48,
              color: isServer ? Colors.blue[700] : Colors.green[700],
            ),
            const SizedBox(height: 8),
            Text(
              isServer ? 'SERVER MOD' : 'CLIENT MOD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isServer ? Colors.blue[700] : Colors.green[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isServer
                  ? 'GPS verilerini paylaşıyorsunuz'
                  : 'GPS verilerini alıyorsunuz',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            if (widget.connectionType == ConnectionType.api) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'WiFi üzerinden bağlantı',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isRunning) {
    final isServer = widget.deviceMode == DeviceMode.server;
    final modeText = isServer ? 'Server' : 'Client';
    final connectionText = widget.connectionType == ConnectionType.api
        ? 'WiFi'
        : 'Bluetooth';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isRunning ? Icons.location_on : Icons.location_off,
              size: 64,
              color: isRunning ? Colors.green[600] : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              isRunning ? 'Aktif' : 'Durduruldu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isRunning ? Colors.green[700] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$modeText - $connectionText',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isServer &&
                isRunning &&
                widget.connectionType == ConnectionType.api) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dns, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Server IP:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ws://${_gpsService.serverIp ?? "..."}:8765',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          '${_gpsService.clientCount} Client Bağlı',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGpsInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  'GPS Bilgileri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (_currentGpsData == null) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Veri bekleniyor...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ),
              ),
            ] else ...[
              _buildInfoRow(
                'Enlem',
                '${_currentGpsData!.latitude.toStringAsFixed(6)}°',
              ),
              _buildInfoRow(
                'Boylam',
                '${_currentGpsData!.longitude.toStringAsFixed(6)}°',
              ),
              if (_currentGpsData!.altitude != null)
                _buildInfoRow(
                  'Yükseklik',
                  '${_currentGpsData!.altitude!.toStringAsFixed(1)} m',
                ),
              if (_currentGpsData!.speed != null)
                _buildInfoRow(
                  'Hız',
                  '${(_currentGpsData!.speed! * 3.6).toStringAsFixed(1)} km/h',
                  icon: _currentGpsData!.speed! < 0.5
                      ? Icons
                            .adjust // Durgun
                      : Icons.speed, // Hareket halinde
                  iconColor: _currentGpsData!.speed! < 0.5
                      ? Colors.grey
                      : Colors.blue,
                ),
              if (_currentGpsData!.bearing != null)
                _buildInfoRow(
                  'Yön',
                  '${_currentGpsData!.bearing!.toStringAsFixed(0)}° ${_getBearingDirection(_currentGpsData!.bearing!)}',
                  icon: Icons.navigation,
                  iconColor: Colors.green,
                  iconRotation: _currentGpsData!.bearing,
                ),
              if (_currentGpsData!.accuracy != null)
                _buildInfoRow(
                  'Doğruluk',
                  '±${_currentGpsData!.accuracy!.toStringAsFixed(1)} m',
                ),
              _buildInfoRow(
                'Zaman',
                '${_currentGpsData!.timestamp.hour.toString().padLeft(2, '0')}:'
                    '${_currentGpsData!.timestamp.minute.toString().padLeft(2, '0')}:'
                    '${_currentGpsData!.timestamp.second.toString().padLeft(2, '0')}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
    double? iconRotation,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Transform.rotate(
                  angle:
                      (iconRotation ?? 0) * 3.14159 / 180, // Derece -> Radyan
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(color: Colors.grey[700], fontSize: 15),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(bool isRunning) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _toggleService,
            style: ElevatedButton.styleFrom(
              backgroundColor: isRunning ? Colors.red[600] : Colors.green[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            icon: Icon(isRunning ? Icons.stop : Icons.play_arrow, size: 28),
            label: Text(
              isRunning ? 'Durdur' : 'Başlat',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  String _getBearingDirection(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'K'; // Kuzey
    if (bearing >= 22.5 && bearing < 67.5) return 'KD'; // Kuzeydoğu
    if (bearing >= 67.5 && bearing < 112.5) return 'D'; // Doğu
    if (bearing >= 112.5 && bearing < 157.5) return 'GD'; // Güneydoğu
    if (bearing >= 157.5 && bearing < 202.5) return 'G'; // Güney
    if (bearing >= 202.5 && bearing < 247.5) return 'GB'; // Güneybatı
    if (bearing >= 247.5 && bearing < 292.5) return 'B'; // Batı
    if (bearing >= 292.5 && bearing < 337.5) return 'KB'; // Kuzeybatı
    return '';
  }
}
