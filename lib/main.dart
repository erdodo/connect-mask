import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/setup_wizard_screen.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'models/device_mode.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sistem UI ayarları
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Ayarları yükle
  final settingsService = SettingsService();
  await settingsService.init();

  // Kurulum tamamlandı mı kontrol et
  final isSetupCompleted = settingsService.isSetupCompleted();
  final deviceMode = settingsService.getDeviceMode();
  final connectionType = settingsService.getConnectionType();

  runApp(
    MyApp(
      isSetupCompleted: isSetupCompleted,
      deviceMode: deviceMode,
      connectionType: connectionType,
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool isSetupCompleted;
  final DeviceMode? deviceMode;
  final ConnectionType? connectionType;

  const MyApp({
    super.key,
    required this.isSetupCompleted,
    this.deviceMode,
    this.connectionType,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Client',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: isSetupCompleted && deviceMode != null && connectionType != null
          ? HomeScreen(deviceMode: deviceMode!, connectionType: connectionType!)
          : const SetupWizardScreen(),
    );
  }
}
