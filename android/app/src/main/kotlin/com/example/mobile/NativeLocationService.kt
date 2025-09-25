package com.example.mobile

import android.app.*
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class NativeLocationService : Service() {
    private lateinit var fusedClient: FusedLocationProviderClient
    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let { loc ->
                Log.d(TAG, "Native location: ${loc.latitude}, ${loc.longitude}")
                pushLocation(loc)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
        startForeground(NOTIFICATION_ID, buildNotification("Starting location tracking"))
        requestUpdates()
    }

    private fun requestUpdates() {
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 60_000L)
            .setMinUpdateIntervalMillis(60_000L)
            .setMinUpdateDistanceMeters(5f)
            .build()
        try {
            fusedClient.requestLocationUpdates(request, callback, mainLooper)
            Log.d(TAG, "Location updates requested")
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing location permission: ${e.message}")
        }
    }

    private fun buildNotification(content: String): Notification {
        val channelId = CHANNEL_ID
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Tracking", NotificationManager.IMPORTANCE_LOW)
            channel.setShowBadge(false)
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("Tourist Safety Tracking")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun pushLocation(location: Location) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val touristId = prefs.getString("flutter.tourist_id", null)
        if (touristId == null) {
            Log.d(TAG, "No tourist_id stored; skipping push")
            return
        }
        val json = JSONObject().apply {
            put("tourist_id", touristId.toIntOrNull() ?: return)
            put("latitude", location.latitude)
            put("longitude", location.longitude)
        }
        val body = json.toString().toRequestBody("application/json".toMediaType())
        val req = Request.Builder()
            .url("http://159.89.166.91:8000/locations/update")
            .post(body)
            .build()
        client.newCall(req).enqueue(object : okhttp3.Callback {
            override fun onFailure(call: okhttp3.Call, e: java.io.IOException) {
                Log.e(TAG, "Location push failed: ${e.message}")
            }
            override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                response.close()
                Log.d(TAG, "Location push response: ${response.code}")
                updateNotification("Tracking active: ${location.latitude.format(5)}, ${location.longitude.format(5)}")
            }
        })
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onDestroy() {
        fusedClient.removeLocationUpdates(callback)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val TAG = "NativeLocationService"
        private const val CHANNEL_ID = "native_tracking"
        private const val NOTIFICATION_ID = 2001
        const val ACTION_STOP = "com.example.mobile.ACTION_STOP"
        private val client = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .writeTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()
    }
}

private fun Double.format(decimals: Int) = String.format("%.${decimals}f", this)
