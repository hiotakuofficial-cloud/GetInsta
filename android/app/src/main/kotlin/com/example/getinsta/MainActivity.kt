package com.example.getinsta

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.getinsta/share"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedUrl" -> {
                    val sharedUrl = intent.getStringExtra("shared_url")
                    result.success(sharedUrl)
                }
                else -> result.notImplemented()
            }
        }
        
        // Check if app was opened with shared URL
        val sharedUrl = intent.getStringExtra("shared_url")
        if (sharedUrl != null) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onUrlShared", sharedUrl)
        }
    }
}
