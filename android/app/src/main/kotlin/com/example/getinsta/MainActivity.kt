package com.example.getinsta

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.getinsta/share"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Check if launched with shared URL
        val sharedUrl = intent.getStringExtra("SHARED_URL")
        val autoDownload = intent.getBooleanExtra("AUTO_DOWNLOAD", false)
        
        if (sharedUrl != null && autoDownload) {
            // Send to Flutter for background download
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("handleAutoDownload", sharedUrl)
        }
    }
}
