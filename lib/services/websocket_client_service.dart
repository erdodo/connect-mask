import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../models/gps_data.dart';

/// WebSocket Client servisi - Server'dan GPS verisi alır
class WebSocketClientService {
  WebSocketChannel? _channel;
  String? _serverUrl;
  bool _isConnected = false;
  StreamSubscription? _wsSubscription;

  final _gpsDataController = StreamController<GpsData>.broadcast();
  Stream<GpsData> get gpsDataStream => _gpsDataController.stream;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _isConnected;

  /// Server'a bağlanır
  Future<bool> connect(String serverIp, int port) async {
    try {
      _serverUrl = 'ws://$serverIp:$port';
      print('🔗 WebSocket bağlantısı kuruluyor: $_serverUrl');

      // WebSocket bağlantısı kur
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl!));

      // Bağlantıyı dinle
      _wsSubscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          print('❌ WebSocket hatası: $error');
          _handleDisconnection();
        },
        onDone: () {
          print('⚠️ WebSocket bağlantısı kapandı');
          _handleDisconnection();
        },
      );

      // Bağlantı kurulduğunu işaretle
      _isConnected = true;
      _connectionController.add(true);
      print('✅ WebSocket bağlantısı kuruldu: $_serverUrl');

      return true;
    } catch (e) {
      print('❌ WebSocket bağlantı hatası: $e');
      _handleDisconnection();
      return false;
    }
  }

  /// Mesajları işler
  void _handleMessage(dynamic message) {
    try {
      final jsonData = jsonDecode(message as String) as Map<String, dynamic>;
      final gpsData = GpsData.fromJson(jsonData);
      _gpsDataController.add(gpsData);
      print('📍 GPS verisi alındı: ${gpsData.latitude}, ${gpsData.longitude}');
    } catch (e) {
      print('⚠️ Mesaj parse hatası: $e');
    }
  }

  /// Bağlantı kesilmesini işler
  void _handleDisconnection() {
    _isConnected = false;
    _connectionController.add(false);
    _wsSubscription?.cancel();
    _channel = null;
  }

  /// Bağlantıyı keser
  void disconnect() {
    print('🛑 WebSocket bağlantısı kesiliyor...');
    _wsSubscription?.cancel();
    _channel?.sink.close();
    _handleDisconnection();
  }

  /// Otomatik server keşfi (HTTP ping ile)
  Future<String?> discoverServer(int port) async {
    print('🔍 Server aranıyor...');

    try {
      // Yerel IP'yi al
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      List<String> subnetsToScan = [];

      for (var interface in interfaces) {
        print('🔍 Interface: ${interface.name}');
        for (var addr in interface.addresses) {
          if (addr.isLoopback) continue;

          final ip = addr.address;
          print('   IP: $ip');

          // Özel IP aralıklarını kontrol et
          if (ip.startsWith('192.168.') ||
              ip.startsWith('172.') ||
              ip.startsWith('10.')) {
            final subnet = ip.substring(0, ip.lastIndexOf('.'));

            if (!subnetsToScan.contains(subnet)) {
              subnetsToScan.add(subnet);
              print('   📡 Taranacak subnet: $subnet.x');
            }
          }
        }
      }

      if (subnetsToScan.isEmpty) {
        print('❌ Taranacak subnet bulunamadı!');
        return null;
      }

      print(
        '🔍 ${subnetsToScan.length} subnet taranacak: ${subnetsToScan.join(", ")}',
      );

      // Tüm subnet'leri paralel tara
      for (var subnet in subnetsToScan) {
        print('🔍 Taranıyor: $subnet.x');

        // Subnet içinde tara (1-254 arası)
        for (int i = 1; i <= 254; i++) {
          final testIp = '$subnet.$i';
          final testUrl = 'http://$testIp:$port';

          try {
            final response = await http
                .get(Uri.parse('$testUrl/ping'))
                .timeout(const Duration(milliseconds: 200));

            if (response.statusCode == 200) {
              final json = jsonDecode(response.body);
              if (json['server'] == 'GPS WebSocket Server') {
                print('✅ Server bulundu: $testIp');
                return testIp;
              }
            }
          } catch (e) {
            // Devam et (timeout veya bağlantı hatası normal)
          }
        }
      }
    } catch (e) {
      print('❌ Otomatik keşif hatası: $e');
    }

    print('❌ Server bulunamadı');
    return null;
  }

  void dispose() {
    disconnect();
    _gpsDataController.close();
    _connectionController.close();
  }
}
