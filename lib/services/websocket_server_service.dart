import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/gps_data.dart';

/// WebSocket Server servisi - GPS verilerini broadcast eder
class WebSocketServerService {
  static const int PORT = 8765;
  HttpServer? _server;
  String? _serverIp;
  final List<WebSocketChannel> _clients = [];

  String? get serverIp => _serverIp;
  int get clientCount => _clients.length;

  /// Server'ı başlatır
  Future<bool> startServer() async {
    try {
      // Yerel IP'yi al
      _serverIp = await _getLocalIp();
      if (_serverIp == null) {
        print('❌ Yerel IP alınamadı!');
        return false;
      }

      // WebSocket handler
      final wsHandler = webSocketHandler((WebSocketChannel webSocket) {
        print('✅ Yeni client bağlandı. Toplam client: ${_clients.length + 1}');

        _clients.add(webSocket);

        // Client bağlantısı kesildiğinde
        webSocket.stream.listen(
          (message) {
            // Client'tan gelen mesajları işle (şimdilik sadece dinle)
            print('📨 Client mesajı: $message');
          },
          onDone: () {
            _clients.remove(webSocket);
            print('❌ Client ayrıldı. Kalan client: ${_clients.length}');
          },
          onError: (error) {
            _clients.remove(webSocket);
            print('⚠️ Client hatası: $error');
          },
        );
      });

      // Ping endpoint (HTTP için)
      final handler = Cascade()
          .add((Request request) {
            if (request.url.path == 'ping') {
              return Response.ok(
                jsonEncode({
                  'server': 'GPS WebSocket Server',
                  'version': '2.0',
                }),
                headers: {'Content-Type': 'application/json'},
              );
            }
            return Response.notFound('Not found');
          })
          .add(wsHandler)
          .handler;

      // Server'ı başlat
      _server = await io.serve(handler, InternetAddress.anyIPv4, PORT);

      print('🚀 WebSocket Server başlatıldı: ws://$_serverIp:$PORT');
      print('📡 HTTP Ping endpoint: http://$_serverIp:$PORT/ping');

      return true;
    } catch (e) {
      print('❌ Server başlatma hatası: $e');
      return false;
    }
  }

  /// GPS verisini tüm client'lara gönderir
  void broadcastGpsData(GpsData gpsData) {
    if (_clients.isEmpty) return;

    final jsonData = jsonEncode(gpsData.toJson());

    // Kopmuş bağlantıları temizle
    _clients.removeWhere((client) {
      try {
        client.sink.add(jsonData);
        return false; // Başarılı, listede kalsın
      } catch (e) {
        print('⚠️ Client\'a veri gönderilemedi, bağlantı kesildi');
        return true; // Hata, listeden çıkar
      }
    });
  }

  /// Server'ı durdurur
  Future<void> stopServer() async {
    // Tüm client bağlantılarını kapat
    for (var client in _clients) {
      await client.sink.close();
    }
    _clients.clear();

    // Server'ı kapat
    await _server?.close(force: true);
    _server = null;
    _serverIp = null;

    print('🛑 WebSocket Server durduruldu');
  }

  /// Yerel IP adresini alır
  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      String? fallbackIp;

      for (var interface in interfaces) {
        print('🔍 Interface: ${interface.name}');
        for (var addr in interface.addresses) {
          print('   IP: ${addr.address}');

          if (addr.isLoopback) continue;

          final ip = addr.address;

          // Özel IP aralıklarını kontrol et (RFC 1918 + Mobil Hotspot)
          // 192.168.x.x - Standart yerel ağ
          // 172.16.x.x - 172.31.x.x - Özel ağ
          // 10.x.x.x - Özel ağ
          // 192.168.43.x - Android hotspot
          // 172.20.10.x - iOS hotspot

          if (ip.startsWith('192.168.') ||
              ip.startsWith('172.') ||
              ip.startsWith('10.')) {
            // Hotspot IP'lerini önceliklendir
            if (ip.startsWith('192.168.43.') || // Android hotspot
                ip.startsWith('172.20.10.') || // iOS hotspot
                ip.startsWith('192.168.137.')) {
              // Windows hotspot
              print('✅ Hotspot IP bulundu: $ip');
              return ip;
            }

            // Standart yerel ağ IP'si
            if (fallbackIp == null) {
              fallbackIp = ip;
            }
          }
        }
      }

      if (fallbackIp != null) {
        print('✅ Yerel IP bulundu: $fallbackIp');
        return fallbackIp;
      }

      print('⚠️ Hiçbir özel IP bulunamadı, ilk geçerli IP alınıyor...');

      // Hiçbir özel IP bulunamazsa ilk geçerli IP'yi al
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            print('✅ Genel IP bulundu: ${addr.address}');
            return addr.address;
          }
        }
      }
    } catch (e) {
      print('❌ IP alma hatası: $e');
    }
    return null;
  }
}
