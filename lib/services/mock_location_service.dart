import 'package:flutter/services.dart';
import '../models/gps_data.dart';

/// Mock location servisini yöneten platform channel servisi
class MockLocationService {
  static const MethodChannel _channel = MethodChannel(
    'com.connect_and_mask/mock_location',
  );

  /// Mock location izninin olup olmadığını kontrol eder
  Future<bool> checkMockLocationPermission() async {
    try {
      final bool hasPermission = await _channel.invokeMethod(
        'checkMockLocationPermission',
      );
      return hasPermission;
    } catch (e) {
      print('Mock location permission check error: $e');
      return false;
    }
  }

  /// Mock location özelliğini başlatır
  Future<bool> startMockLocation() async {
    try {
      final bool success = await _channel.invokeMethod('startMockLocation');
      return success;
    } catch (e) {
      print('Start mock location error: $e');
      return false;
    }
  }

  /// Mock location özelliğini durdurur
  Future<void> stopMockLocation() async {
    try {
      await _channel.invokeMethod('stopMockLocation');
    } catch (e) {
      print('Stop mock location error: $e');
    }
  }

  /// GPS konumunu ayarlar
  Future<bool> setLocation(GpsData data) async {
    try {
      final bool success = await _channel.invokeMethod('setLocation', {
        'latitude': data.latitude,
        'longitude': data.longitude,
        'altitude': data.altitude ?? 0.0,
        'accuracy': data.accuracy ?? 10.0,
        'speed': data.speed ?? 0.0,
        'bearing': data.bearing ?? 0.0,
        'time': data.timestamp.millisecondsSinceEpoch,
      });
      return success;
    } catch (e) {
      print('Set location error: $e');
      return false;
    }
  }

  /// Ayarlar sayfasını açar
  Future<void> openDeveloperSettings() async {
    try {
      await _channel.invokeMethod('openDeveloperSettings');
    } catch (e) {
      print('Open settings error: $e');
    }
  }

  /// Pil optimizasyonu izni ister
  Future<void> requestBatteryExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryExemption');
    } catch (e) {
      print('Request battery exemption error: $e');
    }
  }
}
