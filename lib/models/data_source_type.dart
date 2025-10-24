/// Veri kaynak türleri
enum DataSourceType {
  mockData('Mock Data', 'Sahte GPS verisi kullan'),
  bluetooth('Bluetooth', 'Bluetooth cihazından veri al'),
  api('API', 'Sunucudan veri al');

  final String title;
  final String description;

  const DataSourceType(this.title, this.description);
}
