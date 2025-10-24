import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../models/device_mode.dart';

/// QR kod ile bağlantı ekranı
/// Client: QR kod gösterir (kendi IP'sini)
/// Server: QR kod okur ve client'a bağlanır
class QrConnectionScreen extends StatefulWidget {
  final DeviceMode deviceMode;
  final String? clientIp; // Client modunda kendi IP'si
  final Function(String serverIp)? onServerFound; // Client'ın kullanacağı

  const QrConnectionScreen({
    super.key,
    required this.deviceMode,
    this.clientIp,
    this.onServerFound,
  });

  @override
  State<QrConnectionScreen> createState() => _QrConnectionScreenState();
}

class _QrConnectionScreenState extends State<QrConnectionScreen> {
  MobileScannerController? _scannerController;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    if (widget.deviceMode == DeviceMode.server) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.deviceMode == DeviceMode.client
              ? 'QR Kod - Client'
              : 'QR Kod Okuyucu',
        ),
        backgroundColor: widget.deviceMode == DeviceMode.client
            ? Colors.green[700]
            : Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: widget.deviceMode == DeviceMode.client
          ? _buildClientQrView()
          : _buildServerScannerView(),
    );
  }

  /// Client: QR kod göster
  Widget _buildClientQrView() {
    if (widget.clientIp == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'IP adresi alınıyor...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // QR data: JSON formatında IP ve port
    final qrData = jsonEncode({
      'type': 'gps_client',
      'ip': widget.clientIp,
      'port': 8765,
      'version': '1.0',
    });

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_2, size: 64, color: Colors.green[700]),
            const SizedBox(height: 24),
            Text(
              'Server Cihazla Bağlan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Server cihazdan bu QR kodu okutun',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // QR Kod
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 280,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),

            const SizedBox(height: 32),

            // IP Bilgisi
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi, size: 20, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Client IP Adresi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.clientIp!,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              '💡 Not: Her iki cihaz da aynı WiFi ağında olmalı',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Server: QR kod oku
  Widget _buildServerScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            if (_isScanning) return;

            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final String? code = barcode.rawValue;
              if (code != null) {
                _handleQrCode(code);
                break;
              }
            }
          },
        ),

        // Overlay
        Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
          child: Column(
            children: [
              const Spacer(),

              // Tarama alanı
              Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const Spacer(),

              // Bilgi kartı
              Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 48,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Client QR Kodunu Okutun',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Client cihazda görünen QR kodu kameraya gösterin',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Yükleniyor göstergesi
        if (_isScanning)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Bağlanıyor...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// QR kodu işle
  void _handleQrCode(String code) async {
    setState(() {
      _isScanning = true;
    });

    try {
      // JSON parse et
      final data = jsonDecode(code) as Map<String, dynamic>;

      // Geçerli QR kod mu kontrol et
      if (data['type'] != 'gps_client') {
        _showError('Geçersiz QR kod!');
        return;
      }

      final clientIp = data['ip'] as String?;
      if (clientIp == null) {
        _showError('QR kodda IP bulunamadı!');
        return;
      }

      print('✅ QR koddan client IP alındı: $clientIp');

      // Callback'i çağır ve tamamlanmasını bekle
      if (widget.onServerFound != null) {
        await widget.onServerFound!(clientIp);
        print('✅ Server callback tamamlandı, bağlantı kuruldu');
      }

      // Başarılı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Server bağlandı: $clientIp'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          // Pop with success result
          Navigator.pop(context, clientIp);
        }
      }
    } catch (e) {
      print('❌ QR kod parse hatası: $e');
      _showError('QR kod okunamadı!');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );

    setState(() {
      _isScanning = false;
    });
  }
}
