import 'package:shared_preferences/shared_preferences.dart';
import '../models/data_source_type.dart';
import '../models/device_mode.dart';

/// Uygulama ayarlarını yöneten servis
class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  static const String _keyDataSource = 'data_source';
  static const String _keyAutoStart = 'auto_start';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyDeviceMode = 'device_mode';
  static const String _keyConnectionType = 'connection_type';
  static const String _keySetupCompleted = 'setup_completed';

  /// Servisi başlatır
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Veri kaynağını kaydeder
  Future<void> setDataSource(DataSourceType source) async {
    await _prefs?.setString(_keyDataSource, source.name);
  }

  /// Kayıtlı veri kaynağını getirir
  DataSourceType getDataSource() {
    final sourceName = _prefs?.getString(_keyDataSource);
    if (sourceName == null) return DataSourceType.mockData;

    return DataSourceType.values.firstWhere(
      (e) => e.name == sourceName,
      orElse: () => DataSourceType.mockData,
    );
  }

  /// Otomatik başlatma ayarını kaydeder
  Future<void> setAutoStart(bool value) async {
    await _prefs?.setBool(_keyAutoStart, value);
  }

  /// Otomatik başlatma ayarını getirir
  bool getAutoStart() {
    return _prefs?.getBool(_keyAutoStart) ?? false;
  }

  /// İlk açılış olup olmadığını kontrol eder
  bool isFirstLaunch() {
    return _prefs?.getBool(_keyFirstLaunch) ?? true;
  }

  /// İlk açılış durumunu ayarlar
  Future<void> setFirstLaunch(bool value) async {
    await _prefs?.setBool(_keyFirstLaunch, value);
  }

  /// Cihaz modunu kaydeder
  Future<void> setDeviceMode(DeviceMode mode) async {
    await _prefs?.setString(_keyDeviceMode, mode.name);
  }

  /// Kayıtlı cihaz modunu getirir
  DeviceMode? getDeviceMode() {
    final modeName = _prefs?.getString(_keyDeviceMode);
    if (modeName == null) return null;

    return DeviceMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => DeviceMode.client,
    );
  }

  /// Bağlantı tipini kaydeder
  Future<void> setConnectionType(ConnectionType type) async {
    await _prefs?.setString(_keyConnectionType, type.name);
  }

  /// Kayıtlı bağlantı tipini getirir
  ConnectionType? getConnectionType() {
    final typeName = _prefs?.getString(_keyConnectionType);
    if (typeName == null) return null;

    return ConnectionType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => ConnectionType.api,
    );
  }

  /// Kurulum tamamlandı mı kontrol eder
  bool isSetupCompleted() {
    return _prefs?.getBool(_keySetupCompleted) ?? false;
  }

  /// Kurulum durumunu ayarlar
  Future<void> setSetupCompleted(bool value) async {
    await _prefs?.setBool(_keySetupCompleted, value);
  }

  /// Ayarları sıfırlar
  Future<void> resetSettings() async {
    await _prefs?.clear();
  }
}
