package com.example.getinsta

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.database.Cursor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.getinsta/video_intent"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Handle intent when app is opened with video file
        handleVideoIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleVideoIntent(intent)
    }
    
    private fun handleVideoIntent(intent: Intent?) {
        android.util.Log.d("GetInsta", "handleVideoIntent called")
        android.util.Log.d("GetInsta", "Intent action: ${intent?.action}")
        
        if (intent?.action == Intent.ACTION_VIEW) {
            val uri: Uri? = intent.data
            android.util.Log.d("GetInsta", "URI: $uri")
            
            if (uri != null) {
                val realPath = getRealPathFromURI(uri)
                android.util.Log.d("GetInsta", "Real path: $realPath")
                
                if (realPath != null) {
                    android.util.Log.d("GetInsta", "Real path: $realPath")
                    
                    // Send to video player only
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        android.util.Log.d("GetInsta", "Sending video to Flutter")
                        MethodChannel(messenger, CHANNEL).invokeMethod("openVideo", realPath)
                    } ?: run {
                        android.util.Log.e("GetInsta", "Flutter engine not ready")
                    }
                } else {
                    android.util.Log.e("GetInsta", "Could not get real path from URI")
                }
            }
        }
    }
    
    private fun getRealPathFromURI(uri: Uri): String? {
        android.util.Log.d("GetInsta", "getRealPathFromURI: $uri")
        android.util.Log.d("GetInsta", "URI scheme: ${uri.scheme}")
        
        return when (uri.scheme) {
            "file" -> {
                android.util.Log.d("GetInsta", "File scheme path: ${uri.path}")
                uri.path
            }
            "content" -> {
                try {
                    val projection = arrayOf(MediaStore.MediaColumns.DATA)
                    val cursor: Cursor? = contentResolver.query(uri, projection, null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val columnIndex = it.getColumnIndex(MediaStore.MediaColumns.DATA)
                            if (columnIndex >= 0) {
                                val path = it.getString(columnIndex)
                                android.util.Log.d("GetInsta", "Content scheme path: $path")
                                return path
                            }
                        }
                    }
                    // Fallback: try to use URI path directly
                    val path = uri.path
                    android.util.Log.d("GetInsta", "Fallback path: $path")
                    path
                } catch (e: Exception) {
                    android.util.Log.e("GetInsta", "Error getting path: ${e.message}")
                    uri.toString()
                }
            }
            else -> {
                android.util.Log.d("GetInsta", "Unknown scheme, using toString: ${uri.toString()}")
                uri.toString()
            }
        }
    }
}
