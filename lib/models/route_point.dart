/// Rota noktası modeli
class RoutePoint {
  final double latitude;
  final double longitude;

  RoutePoint(this.latitude, this.longitude);

  @override
  String toString() => 'RoutePoint($latitude, $longitude)';
}
