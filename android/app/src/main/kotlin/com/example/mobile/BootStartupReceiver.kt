package com.example.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootStartupReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON") {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val touristId = prefs.getString("flutter.tourist_id", null)
            if (touristId != null) {
                Log.d("BootStartupReceiver", "Boot completed - restarting NativeLocationService")
                context.startForegroundService(Intent(context, NativeLocationService::class.java))
            } else {
                Log.d("BootStartupReceiver", "No tourist_id at boot; not starting service")
            }
        }
    }
}
