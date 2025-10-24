import 'dart:math';
import '../models/route_point.dart';
import '../models/gps_data.dart';

/// Gerçekçi araç hareketi simülatörü
class RouteSimulator {
  // Sabit rota noktaları (Eskişehir - Odunpazarı bölgesi)
  static final List<RoutePoint> _routePoints = [
    RoutePoint(39.394139, 30.034645),
    RoutePoint(39.394907, 30.034305),
    RoutePoint(39.395725, 30.033952),
    RoutePoint(39.396533, 30.033612),
    RoutePoint(39.397230, 30.033338),
    RoutePoint(39.398089, 30.032985),
    RoutePoint(39.398635, 30.032802),
    RoutePoint(39.399503, 30.032410),
    RoutePoint(39.400382, 30.032017),
    RoutePoint(39.401291, 30.031599),
    RoutePoint(39.402049, 30.031233),
    RoutePoint(39.403140, 30.030475),
    RoutePoint(39.404089, 30.029691),
    RoutePoint(39.404837, 30.029102),
  ];

  int _currentPointIndex = 0;
  bool _isReversing = false;
  double _currentLat = 0;
  double _currentLon = 0;
  double _currentSpeed = 0; // m/s cinsinden
  double _targetSpeed = 0; // m/s cinsinden
  double _currentBearing = 0; // derece
  final Random _random = Random();

  RouteSimulator() {
    _currentLat = _routePoints[0].latitude;
    _currentLon = _routePoints[0].longitude;
    _setNewTargetSpeed();
  }

  /// Sonraki GPS verisini hesaplar (gerçekçi araç hareketi)
  GpsData getNextGpsData() {
    final now = DateTime.now();

    // Hedef noktayı al
    final targetPoint = _routePoints[_currentPointIndex];

    // Hedef noktaya olan mesafeyi hesapla (metre)
    final distance = _calculateDistance(
      _currentLat,
      _currentLon,
      targetPoint.latitude,
      targetPoint.longitude,
    );

    // Hedefe yön açısını hesapla
    final targetBearing = _calculateBearing(
      _currentLat,
      _currentLon,
      targetPoint.latitude,
      targetPoint.longitude,
    );

    // Yumuşak yön değişimi (gerçek araç gibi)
    _currentBearing = _smoothBearingChange(
      _currentBearing,
      targetBearing,
      15.0,
    );

    // Hız değişimini simüle et (gerçek araç gibi ivme/fren)
    _currentSpeed = _smoothSpeedChange(_currentSpeed, _targetSpeed, 2.0);

    // 1 saniyede gidilecek mesafe (m/s * 1s)
    final stepDistance = _currentSpeed;

    if (distance < stepDistance * 2) {
      // Hedefe yaklaştık, sonraki noktaya geç
      _moveToNextPoint();
      _currentLat = targetPoint.latitude;
      _currentLon = targetPoint.longitude;
    } else {
      // Mevcut konumdan hedefe doğru ilerle
      final newPosition = _moveTowards(
        _currentLat,
        _currentLon,
        targetPoint.latitude,
        targetPoint.longitude,
        stepDistance,
      );
      _currentLat = newPosition['lat']!;
      _currentLon = newPosition['lon']!;
    }

    // Rastgele küçük GPS sapması (gerçek GPS gibi)
    final latNoise = (_random.nextDouble() - 0.5) * 0.00001;
    final lonNoise = (_random.nextDouble() - 0.5) * 0.00001;

    return GpsData(
      latitude: _currentLat + latNoise,
      longitude: _currentLon + lonNoise,
      altitude: 785.0 + _random.nextDouble() * 5, // Eskişehir yüksekliği ~785m
      speed: _currentSpeed,
      accuracy: 3.0 + _random.nextDouble() * 4, // 3-7m (gerçekçi GPS doğruluğu)
      bearing: _currentBearing,
      timestamp: now,
    );
  }

  /// Sonraki noktaya geç
  void _moveToNextPoint() {
    if (_isReversing) {
      _currentPointIndex--;
      if (_currentPointIndex <= 0) {
        _currentPointIndex = 0;
        _isReversing = false;
      }
    } else {
      _currentPointIndex++;
      if (_currentPointIndex >= _routePoints.length - 1) {
        _currentPointIndex = _routePoints.length - 1;
        _isReversing = true;
      }
    }

    // Yeni hedef için yeni hız belirle (20-40 km/h arası)
    _setNewTargetSpeed();
  }

  /// Yeni hedef hız belirle (20-40 km/h arası)
  void _setNewTargetSpeed() {
    // 20-40 km/h arası = 5.56-11.11 m/s
    final minSpeed = 20.0 / 3.6; // 5.56 m/s
    final maxSpeed = 40.0 / 3.6; // 11.11 m/s
    _targetSpeed = minSpeed + _random.nextDouble() * (maxSpeed - minSpeed);
  }

  /// İki nokta arası mesafe (metre) - Haversine formülü
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // metre
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// İki nokta arası yön açısı (derece)
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = _toRadians(lon2 - lon1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final y = sin(dLon) * cos(lat2Rad);
    final x =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(y, x);
    return (_toDegrees(bearing) + 360) % 360;
  }

  /// Bir noktadan diğerine belirli mesafe kadar hareket et
  Map<String, double> _moveTowards(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double distance,
  ) {
    const earthRadius = 6371000.0; // metre
    final bearing = _calculateBearing(lat1, lon1, lat2, lon2);
    final bearingRad = _toRadians(bearing);

    final lat1Rad = _toRadians(lat1);
    final lon1Rad = _toRadians(lon1);

    final lat2Rad = asin(
      sin(lat1Rad) * cos(distance / earthRadius) +
          cos(lat1Rad) * sin(distance / earthRadius) * cos(bearingRad),
    );

    final lon2Rad =
        lon1Rad +
        atan2(
          sin(bearingRad) * sin(distance / earthRadius) * cos(lat1Rad),
          cos(distance / earthRadius) - sin(lat1Rad) * sin(lat2Rad),
        );

    return {'lat': _toDegrees(lat2Rad), 'lon': _toDegrees(lon2Rad)};
  }

  /// Yumuşak hız değişimi (gerçek araç ivmesi/freni)
  double _smoothSpeedChange(double current, double target, double maxChange) {
    final diff = target - current;
    if (diff.abs() < maxChange) {
      return target;
    }
    return current + (diff > 0 ? maxChange : -maxChange);
  }

  /// Yumuşak yön değişimi (gerçek araç direksiyon hareketi)
  double _smoothBearingChange(double current, double target, double maxChange) {
    double diff = target - current;

    // 180 dereceden fazla fark varsa kısa yolu al
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    if (diff.abs() < maxChange) {
      return target;
    }

    final newBearing = current + (diff > 0 ? maxChange : -maxChange);
    return (newBearing + 360) % 360;
  }

  double _toRadians(double degrees) => degrees * pi / 180.0;
  double _toDegrees(double radians) => radians * 180.0 / pi;

  /// Rotayı sıfırla
  void reset() {
    _currentPointIndex = 0;
    _isReversing = false;
    _currentLat = _routePoints[0].latitude;
    _currentLon = _routePoints[0].longitude;
    _currentSpeed = 0;
    _targetSpeed = 0;
    _currentBearing = 0;
    _setNewTargetSpeed();
  }

  /// Mevcut bearing değerini al
  double get currentBearing => _currentBearing;
}
