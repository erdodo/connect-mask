/// GPS veri modeli
class GpsData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? accuracy;
  final double? bearing;
  final DateTime timestamp;

  GpsData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.accuracy,
    this.bearing,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'altitude': altitude,
    'speed': speed,
    'accuracy': accuracy,
    'bearing': bearing,
    'timestamp': timestamp.toIso8601String(),
  };

  factory GpsData.fromJson(Map<String, dynamic> json) => GpsData(
    latitude: json['latitude'] as double,
    longitude: json['longitude'] as double,
    altitude: json['altitude'] as double?,
    speed: json['speed'] as double?,
    accuracy: json['accuracy'] as double?,
    bearing: json['bearing'] as double?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  @override
  String toString() {
    return 'GPS: $latitude, $longitude (±${accuracy?.toStringAsFixed(1)}m)';
  }
}
