import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/gps_data.dart';

/// API Client servisi - Server'dan GPS verisi alır
class ApiClientService {
  String? _serverUrl;
  Timer? _pollTimer;
  bool _isConnected = false;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5; // 5 hatadan sonra bağlantıyı kes

  final _gpsDataController = StreamController<GpsData>.broadcast();
  Stream<GpsData> get gpsDataStream => _gpsDataController.stream;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _isConnected;

  /// Server'a bağlanır
  Future<bool> connect(String serverIp, int port) async {
    _serverUrl = 'http://$serverIp:$port';

    // Ping test
    final pingSuccess = await _pingServer();
    if (!pingSuccess) {
      _serverUrl = null;
      return false;
    }

    _isConnected = true;
    _connectionController.add(true);
    _startPolling();
    return true;
  }

  /// Bağlantıyı keser
  void disconnect() {
    _stopPolling();
    _isConnected = false;
    _serverUrl = null;
    _connectionController.add(false);
  }

  /// Server'a ping atar
  Future<bool> _pingServer() async {
    if (_serverUrl == null) return false;

    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/ping'))
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      print('Ping hatası: $e');
      return false;
    }
  }

  /// Polling başlatır (1 saniyede bir GPS verisi çeker)
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _fetchGpsData();
    });
  }

  /// Polling durdurur
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// GPS verisini çeker
  Future<void> _fetchGpsData() async {
    if (_serverUrl == null || !_isConnected) return;

    try {
      final response = await http
          .get(Uri.parse('$_serverUrl/gps'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final gpsData = GpsData.fromJson(jsonData);
        _gpsDataController.add(gpsData);
      } else {
        print('GPS verisi alınamadı: ${response.statusCode}');
      }
    } catch (e) {
      print('GPS çekme hatası: $e');
      // Bağlantı hatası - tekrar ping dene
      final pingSuccess = await _pingServer();
      if (!pingSuccess) {
        disconnect();
      }
    }
  }

  /// Otomatik server keşfi (yerel ağda tarama)
  Future<String?> discoverServer(int port) async {
    try {
      // Yerel IP'yi al
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            final subnet = addr.address.substring(
              0,
              addr.address.lastIndexOf('.'),
            );

            // Subnet içinde tara (1-254 arası)
            for (int i = 1; i <= 254; i++) {
              final testIp = '$subnet.$i';
              final testUrl = 'http://$testIp:$port';

              try {
                final response = await http
                    .get(Uri.parse('$testUrl/ping'))
                    .timeout(const Duration(milliseconds: 500));

                if (response.statusCode == 200) {
                  final json = jsonDecode(response.body);
                  if (json['server'] == 'GPS Server') {
                    return testIp;
                  }
                }
              } catch (e) {
                // Devam et
              }
            }
          }
        }
      }
    } catch (e) {
      print('Otomatik keşif hatası: $e');
    }
    return null;
  }

  void dispose() {
    disconnect();
    _gpsDataController.close();
    _connectionController.close();
  }
}
