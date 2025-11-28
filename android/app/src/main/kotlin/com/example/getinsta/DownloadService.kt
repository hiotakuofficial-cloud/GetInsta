package com.example.getinsta

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.widget.Toast
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.URL

class DownloadService : Service() {
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val sharedUrl = intent?.getStringExtra("SHARED_URL")
        
        if (sharedUrl != null) {
            // Start download in background
            CoroutineScope(Dispatchers.IO).launch {
                downloadInstagramMedia(sharedUrl)
                stopSelf() // Stop service when done
            }
        }
        
        return START_NOT_STICKY
    }
    
    private suspend fun downloadInstagramMedia(url: String) {
        try {
            // Fetch Instagram data
            val apiUrl = "https://v1-w3sc.onrender.com/insta/api.php?action=url&url=${java.net.URLEncoder.encode(url, "UTF-8")}"
            val response = URL(apiUrl).readText()
            val data = JSONObject(response)
            
            if (data.getBoolean("success") && data.has("download_links")) {
                val downloadUrl = data.getJSONArray("download_links").getString(0)
                val filename = "instagram_${System.currentTimeMillis()}.mp4"
                
                // Download file
                val downloadDir = File("/storage/emulated/0/Download")
                if (!downloadDir.exists()) {
                    downloadDir.mkdirs()
                }
                
                val file = File(downloadDir, filename)
                val inputStream = URL(downloadUrl).openStream()
                val outputStream = FileOutputStream(file)
                
                inputStream.copyTo(outputStream)
                inputStream.close()
                outputStream.close()
                
                // Show complete toast on main thread
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@DownloadService, "Complete...", Toast.LENGTH_SHORT).show()
                }
            } else {
                withContext(Dispatchers.Main) {
                    Toast.makeText(this@DownloadService, "Download failed", Toast.LENGTH_SHORT).show()
                }
            }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                Toast.makeText(this@DownloadService, "Download failed", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
