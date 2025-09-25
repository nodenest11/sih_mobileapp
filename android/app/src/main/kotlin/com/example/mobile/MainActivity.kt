package com.example.mobile

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "native_location_service"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			when (call.method) {
				"start" -> {
					val intent = Intent(this, NativeLocationService::class.java)
					startForegroundService(intent)
					result.success(true)
				}
				"stop" -> {
					val intent = Intent(this, NativeLocationService::class.java)
					intent.action = NativeLocationService.ACTION_STOP
					startService(intent)
					result.success(true)
				}
				else -> result.notImplemented()
			}
		}
	}
}
