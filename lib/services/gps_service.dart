import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/gps_data.dart';
import '../models/device_mode.dart';
import 'mock_location_service.dart';
import 'websocket_server_service.dart';
import 'websocket_client_service.dart';

/// GPS veri servisi - Server veya Client modunda çalışır
class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance;
  GpsService._internal();

  final MockLocationService _mockLocationService = MockLocationService();
  final WebSocketServerService _wsServerService = WebSocketServerService();
  final WebSocketClientService _wsClientService = WebSocketClientService();

  DeviceMode? _deviceMode;
  ConnectionType? _connectionType;
  bool _isRunning = false;
  Timer? _gpsTimer;
  StreamSubscription? _clientSubscription;

  final _gpsStreamController = StreamController<GpsData>.broadcast();
  Stream<GpsData> get gpsStream => _gpsStreamController.stream;

  bool get isRunning => _isRunning;
  DeviceMode? get deviceMode => _deviceMode;
  ConnectionType? get connectionType => _connectionType;
  String? get serverIp => _wsServerService.serverIp;
  int get clientCount => _wsServerService.clientCount;

  /// Servisi başlatır
  Future<bool> start({
    required DeviceMode mode,
    required ConnectionType connection,
    String? serverIp,
  }) async {
    if (_isRunning) return true;

    _deviceMode = mode;
    _connectionType = connection;

    if (mode == DeviceMode.server) {
      return await _startServer();
    } else {
      return await _startClient(serverIp: serverIp);
    }
  }

  /// Server modunu başlatır
  Future<bool> _startServer() async {
    print('🚀 Server modu başlatılıyor...');

    // Konum izinlerini kontrol et
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      print('❌ Konum izni yok!');
      return false;
    }

    // WebSocket Server'ı başlat
    bool serverStarted = await _wsServerService.startServer();
    print(
      '📡 WebSocket Server başlatıldı: ws://${_wsServerService.serverIp}:${WebSocketServerService.PORT}',
    );

    if (!serverStarted) {
      print('❌ Server başlatılamadı!');
      return false;
    }

    _isRunning = true;

    // Gerçek GPS verilerini okuyup server'dan yayınla
    _startReadingRealGps();

    return true;
  }

  /// Client modunu başlatır
  Future<bool> _startClient({String? serverIp}) async {
    print('📱 Client modu başlatılıyor...');

    // Mock location iznini kontrol et
    final hasMockPermission = await _mockLocationService
        .checkMockLocationPermission();
    if (!hasMockPermission) {
      print('❌ Mock location izni yok!');
      return false;
    }

    // Mock location'ı başlat
    final mockStarted = await _mockLocationService.startMockLocation();
    if (!mockStarted) {
      print('❌ Mock location başlatılamadı!');
      return false;
    }

    // WebSocket Client'ı başlat ve server'a bağlan
    bool connected = false;
    if (serverIp != null) {
      connected = await _wsClientService.connect(
        serverIp,
        WebSocketServerService.PORT,
      );
    } else {
      // Auto-discovery
      final discoveredIp = await _wsClientService.discoverServer(
        WebSocketServerService.PORT,
      );
      if (discoveredIp != null) {
        connected = await _wsClientService.connect(
          discoveredIp,
          WebSocketServerService.PORT,
        );
      }
    }

    if (connected) {
      print(
        '✅ WebSocket Server\'a bağlanıldı: ws://$serverIp:${WebSocketServerService.PORT}',
      );

      // Server'dan gelen verileri dinle (WebSocket sürekli açık)
      _clientSubscription = _wsClientService.gpsDataStream.listen((gpsData) {
        print(
          '📍 Server\'dan GPS verisi alındı: ${gpsData.latitude}, ${gpsData.longitude}',
        );

        // Cihazın GPS'ini bu verilerle güncelle
        _mockLocationService.setLocation(gpsData);

        // Stream'e gönder
        _gpsStreamController.add(gpsData);
      });
    } else {
      print('❌ Server bulunamadı!');
      await _mockLocationService.stopMockLocation();
      return false;
    }

    _isRunning = true;
    return true;
  }

  /// Gerçek GPS verilerini okur (Server modu için)
  void _startReadingRealGps() {
    _gpsTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        // Gerçek konumu al
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        );

        // Hız ve yön düzeltmesi
        // heading: -1 ise (bilinmiyor) ve hız çok düşükse (hareket etmiyor), 0 olarak ayarla
        double correctedSpeed = position.speed;
        double correctedBearing = position.heading;

        // Hız 0.5 m/s'den düşükse (yaklaşık 1.8 km/h) hareket etmiyor kabul et
        if (correctedSpeed < 0.5) {
          correctedSpeed = 0.0;
          // Hareket etmiyorsa yön bilgisi anlamsız, önceki yönü koru veya 0 yap
          if (correctedBearing < 0) {
            correctedBearing = 0.0;
          }
        } else {
          // Hareket varken de heading -1 ise (bazı cihazlarda oluyor), 0 yap
          if (correctedBearing < 0) {
            correctedBearing = 0.0;
          }
        }

        final gpsData = GpsData(
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          accuracy: position.accuracy,
          speed: correctedSpeed,
          bearing: correctedBearing,
          timestamp: position.timestamp,
        );

        print(
          '📍 GPS: ${gpsData.latitude.toStringAsFixed(6)}, ${gpsData.longitude.toStringAsFixed(6)} | '
          '🎯 Doğruluk: ${(gpsData.accuracy ?? 0).toStringAsFixed(1)}m | '
          '🚗 Hız: ${((gpsData.speed ?? 0) * 3.6).toStringAsFixed(1)} km/h | '
          '🧭 Yön: ${(gpsData.bearing ?? 0).toStringAsFixed(0)}° | '
          '👥 ${_wsServerService.clientCount} client',
        );

        // WebSocket'ten yayınla
        _wsServerService.broadcastGpsData(gpsData);

        // Stream'e gönder
        _gpsStreamController.add(gpsData);
      } catch (e) {
        print('❌ GPS okuma hatası: $e');
      }
    });
  }

  /// Konum iznini kontrol eder
  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Mock location iznini kontrol eder
  Future<bool> checkMockPermission() async {
    return await _mockLocationService.checkMockLocationPermission();
  }

  /// Ayarlar sayfasını açar
  Future<void> openSettings() async {
    await _mockLocationService.openDeveloperSettings();
  }

  /// Pil optimizasyonu izni ister
  Future<void> requestBatteryExemption() async {
    await _mockLocationService.requestBatteryExemption();
  }

  /// Servisi durdurur
  Future<void> stop() async {
    _isRunning = false;
    _gpsTimer?.cancel();
    _gpsTimer = null;

    await _clientSubscription?.cancel();
    _clientSubscription = null;

    if (_deviceMode == DeviceMode.server) {
      await _wsServerService.stopServer();
    } else {
      _wsClientService.disconnect();
      await _mockLocationService.stopMockLocation();
    }

    _deviceMode = null;
    _connectionType = null;
  }

  void dispose() {
    stop();
    _gpsStreamController.close();
    _wsClientService.dispose();
  }
}
