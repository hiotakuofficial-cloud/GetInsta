package com.example.getinsta

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class ShareReceiverActivity : FlutterActivity() {
    private val CHANNEL = "com.example.getinsta/share"
    private var sharedUrl: String? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check overlay permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            startActivity(intent)
            finish()
            return
        }
        
        // Extract shared URL immediately
        sharedUrl = extractSharedUrl(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sharedUrl = extractSharedUrl(intent)
    }
    
    private fun extractSharedUrl(intent: Intent?): String? {
        return if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else null
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedUrl" -> {
                    result.success(sharedUrl)
                }
                "closeOverlay" -> {
                    finish()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    override fun getInitialRoute(): String {
        return "/system_overlay"
    }
}
