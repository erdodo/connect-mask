import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../models/gps_data.dart';

/// API Server servisi - GPS verilerini HTTP üzerinden paylaşır
class ApiServerService {
  static const int PORT = 8765; // Sabit port

  HttpServer? _server;
  GpsData? _lastGpsData;
  bool _isRunning = false;
  String? _serverIp;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isRunning => _isRunning;
  String? get serverIp => _serverIp;
  int get port => PORT;

  /// Server'ı başlatır
  Future<bool> startServer() async {
    if (_isRunning) return true;

    try {
      // IP adresini al
      _serverIp = await _getLocalIpAddress();
      if (_serverIp == null) {
        print('IP adresi alınamadı!');
        return false;
      }

      // HTTP server'ı başlat
      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addHandler(_handleRequest);

      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, PORT);

      _isRunning = true;
      print('GPS Server başlatıldı: http://$_serverIp:$PORT');
      return true;
    } catch (e) {
      print('Server başlatma hatası: $e');
      return false;
    }
  }

  /// Server'ı durdurur
  Future<void> stopServer() async {
    if (!_isRunning) return;

    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _serverIp = null;
    _lastGpsData = null;
    print('GPS Server durduruldu');
  }

  /// GPS verisini günceller
  void updateGpsData(GpsData data) {
    _lastGpsData = data;
  }

  /// HTTP request'leri işler
  Response _handleRequest(Request request) {
    if (request.method == 'GET' && request.url.path == 'gps') {
      if (_lastGpsData == null) {
        return Response.notFound(
          jsonEncode({'error': 'GPS verisi yok'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final jsonData = jsonEncode(_lastGpsData!.toJson());
      _connectionController.add(true);

      return Response.ok(
        jsonData,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    if (request.method == 'GET' && request.url.path == 'ping') {
      return Response.ok(
        jsonEncode({'status': 'ok', 'server': 'GPS Server'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    return Response.notFound('Endpoint bulunamadı');
  }

  /// Yerel IP adresini alır
  Future<String?> _getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            // WiFi veya ethernet adresini tercih et
            if (interface.name.contains('wlan') ||
                interface.name.contains('eth') ||
                interface.name.contains('en')) {
              return addr.address;
            }
          }
        }
      }

      // Hiç bulunamazsa ilk IPv4 adresini döndür
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (e) {
      print('IP adresi alma hatası: $e');
    }
    return null;
  }

  void dispose() {
    stopServer();
    _connectionController.close();
  }
}
