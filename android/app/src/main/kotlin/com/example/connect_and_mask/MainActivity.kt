package com.example.connect_and_mask

import android.Manifest
import android.app.AppOpsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.connect_and_mask/mock_location"
    private val LOCATION_PERMISSION_REQUEST_CODE = 1001
    private var locationManager: LocationManager? = null
    private var mockLocationService: MockLocationService? = null
    private var serviceBound = false

    private val serviceConnection =
            object : ServiceConnection {
                override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
                    val binder = service as MockLocationService.LocalBinder
                    mockLocationService = binder.getService()
                    serviceBound = true
                }

                override fun onServiceDisconnected(name: ComponentName?) {
                    mockLocationService = null
                    serviceBound = false
                }
            }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call,
                result ->
            when (call.method) {
                "checkMockLocationPermission" -> {
                    result.success(checkMockLocationPermission())
                }
                "startMockLocation" -> {
                    if (checkLocationPermissions()) {
                        requestBatteryOptimizationExemption()
                        val success = startMockLocationService()
                        result.success(success)
                    } else {
                        requestLocationPermissions()
                        result.success(false)
                    }
                }
                "stopMockLocation" -> {
                    stopMockLocationService()
                    result.success(true)
                }
                "setLocation" -> {
                    val latitude = call.argument<Double>("latitude") ?: 0.0
                    val longitude = call.argument<Double>("longitude") ?: 0.0
                    val altitude = call.argument<Double>("altitude") ?: 0.0
                    val accuracy = call.argument<Double>("accuracy") ?: 10.0
                    val speed = call.argument<Double>("speed") ?: 0.0
                    val bearing = call.argument<Double>("bearing") ?: 0.0
                    val time = call.argument<Long>("time") ?: System.currentTimeMillis()

                    val success =
                            mockLocationService?.updateLocation(
                                    latitude,
                                    longitude,
                                    altitude,
                                    accuracy.toFloat(),
                                    speed.toFloat(),
                                    bearing.toFloat(),
                                    time
                            )
                                    ?: false
                    result.success(success)
                }
                "openDeveloperSettings" -> {
                    openDeveloperSettings()
                    result.success(true)
                }
                "requestBatteryExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkMockLocationPermission(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val opsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                val mode =
                        opsManager.checkOpNoThrow(
                                AppOpsManager.OPSTR_MOCK_LOCATION,
                                android.os.Process.myUid(),
                                packageName
                        )
                mode == AppOpsManager.MODE_ALLOWED
            } else {
                // Android 6.0 altında mock location ayarlarını kontrol et
                !Settings.Secure.getString(contentResolver, Settings.Secure.ALLOW_MOCK_LOCATION)
                        .equals("0")
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun checkLocationPermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
    }

    private fun requestLocationPermissions() {
        ActivityCompat.requestPermissions(
                this,
                arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                LOCATION_PERMISSION_REQUEST_CODE
        )
    }

    private fun startMockLocationService(): Boolean {
        if (!checkMockLocationPermission()) {
            return false
        }

        // Foreground service'i başlat
        val intent = Intent(this, MockLocationService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }

        // Service'e bağlan
        bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)

        // Biraz bekle ve mock location'ı etkinleştir
        android.os.Handler(mainLooper)
                .postDelayed({ mockLocationService?.enableMockLocation() }, 500)

        return true
    }

    private fun stopMockLocationService() {
        mockLocationService?.disableMockLocation()

        if (serviceBound) {
            unbindService(serviceConnection)
            serviceBound = false
        }

        val intent = Intent(this, MockLocationService::class.java)
        stopService(intent)

        mockLocationService = null
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = packageName

            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                } catch (e: Exception) {
                    // Kullanıcıyı genel ayarlara yönlendir
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                    } catch (e2: Exception) {
                        // Ignore
                    }
                }
            }
        }
    }

    private fun openDeveloperSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            // Alternatif olarak normal ayarları aç
            try {
                val intent = Intent(Settings.ACTION_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
            } catch (e2: Exception) {
                // Hiçbir şey yapma
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMockLocationService()
    }
}
