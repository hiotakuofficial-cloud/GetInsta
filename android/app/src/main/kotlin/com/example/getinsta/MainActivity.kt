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
        if (intent?.action == Intent.ACTION_VIEW) {
            val uri: Uri? = intent.data
            if (uri != null) {
                val realPath = getRealPathFromURI(uri)
                if (realPath != null) {
                    // Check if it's audio or video file
                    val mimeType = contentResolver.getType(uri)
                    val isAudio = mimeType?.startsWith("audio/") == true || 
                                 realPath.endsWith(".mp3", true) || 
                                 realPath.endsWith(".m4a", true) ||
                                 realPath.endsWith(".wav", true) ||
                                 realPath.endsWith(".flac", true)
                    
                    // Send to appropriate player
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        if (isAudio) {
                            MethodChannel(messenger, CHANNEL).invokeMethod("openAudio", realPath)
                        } else {
                            MethodChannel(messenger, CHANNEL).invokeMethod("openVideo", realPath)
                        }
                    }
                }
            }
        }
    }
    
    private fun getRealPathFromURI(uri: Uri): String? {
        return when (uri.scheme) {
            "file" -> uri.path
            "content" -> {
                val projection = arrayOf(MediaStore.Video.Media.DATA)
                val cursor: Cursor? = contentResolver.query(uri, projection, null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val columnIndex = it.getColumnIndexOrThrow(MediaStore.Video.Media.DATA)
                        return it.getString(columnIndex)
                    }
                }
                null
            }
            else -> null
        }
    }
}
