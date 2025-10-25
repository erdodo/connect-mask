package com.example.connect_and_mask

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.location.LocationManager
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import androidx.core.app.NotificationCompat

class MockLocationService : Service() {
    private val binder = LocalBinder()
    private var locationManager: LocationManager? = null
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "mock_location_channel"

    inner class LocalBinder : Binder() {
        fun getService(): MockLocationService = this@MockLocationService
    }

    override fun onCreate() {
        super.onCreate()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification())
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(
                                    CHANNEL_ID,
                                    "Mock Location Service",
                                    NotificationManager.IMPORTANCE_LOW
                            )
                            .apply {
                                description = "Sahte konum servisi çalışıyor"
                                setShowBadge(false)
                            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        notificationIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Connect & Mask Çalışıyor")
                .setContentText("GPS paylaşımı aktif")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .build()
    }

    fun updateLocation(
            latitude: Double,
            longitude: Double,
            altitude: Double,
            accuracy: Float,
            speed: Float,
            bearing: Float,
            time: Long
    ): Boolean {
        return try {
            val location =
                    Location(LocationManager.GPS_PROVIDER).apply {
                        this.latitude = latitude
                        this.longitude = longitude
                        this.altitude = altitude
                        this.accuracy = accuracy
                        this.speed = speed
                        this.bearing = bearing
                        this.time = time
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                            this.elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                        }
                    }

            locationManager?.setTestProviderLocation(LocationManager.GPS_PROVIDER, location)

            val networkLocation =
                    Location(LocationManager.NETWORK_PROVIDER).apply {
                        this.latitude = latitude
                        this.longitude = longitude
                        this.altitude = altitude
                        this.accuracy = accuracy * 2
                        this.speed = speed
                        this.bearing = bearing
                        this.time = time
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                            this.elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos()
                        }
                    }
            locationManager?.setTestProviderLocation(
                    LocationManager.NETWORK_PROVIDER,
                    networkLocation
            )

            true
        } catch (e: Exception) {
            false
        }
    }

    fun enableMockLocation(): Boolean {
        return try {
            locationManager?.let { lm ->
                try {
                    lm.addTestProvider(
                            LocationManager.GPS_PROVIDER,
                            false,
                            false,
                            false,
                            false,
                            true,
                            true,
                            true,
                            android.location.Criteria.POWER_LOW,
                            android.location.Criteria.ACCURACY_FINE
                    )
                    lm.setTestProviderEnabled(LocationManager.GPS_PROVIDER, true)

                    lm.addTestProvider(
                            LocationManager.NETWORK_PROVIDER,
                            false,
                            false,
                            false,
                            false,
                            true,
                            true,
                            true,
                            android.location.Criteria.POWER_LOW,
                            android.location.Criteria.ACCURACY_FINE
                    )
                    lm.setTestProviderEnabled(LocationManager.NETWORK_PROVIDER, true)
                    true
                } catch (e: Exception) {
                    try {
                        lm.setTestProviderEnabled(LocationManager.GPS_PROVIDER, true)
                        lm.setTestProviderEnabled(LocationManager.NETWORK_PROVIDER, true)
                        true
                    } catch (e2: Exception) {
                        false
                    }
                }
            }
                    ?: false
        } catch (e: Exception) {
            false
        }
    }

    fun disableMockLocation() {
        try {
            locationManager?.let { lm ->
                try {
                    lm.setTestProviderEnabled(LocationManager.GPS_PROVIDER, false)
                    lm.removeTestProvider(LocationManager.GPS_PROVIDER)
                } catch (e: Exception) {
                    // Ignore
                }

                try {
                    lm.setTestProviderEnabled(LocationManager.NETWORK_PROVIDER, false)
                    lm.removeTestProvider(LocationManager.NETWORK_PROVIDER)
                } catch (e: Exception) {
                    // Ignore
                }
            }
        } catch (e: Exception) {
            // Ignore
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        disableMockLocation()
    }
}
