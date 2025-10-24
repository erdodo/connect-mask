/// Cihaz modu
enum DeviceMode {
  server('Server', 'GPS verisi paylaş'),
  client('Client', 'GPS verisi al');

  final String title;
  final String description;

  const DeviceMode(this.title, this.description);
}

/// Bağlantı tipi
enum ConnectionType {
  api('WiFi', 'Yerel ağ üzerinden bağlan');

  final String title;
  final String description;

  const ConnectionType(this.title, this.description);
}

/// Bağlantı durumu
enum ConnectionStatus { disconnected, connecting, connected, error }
