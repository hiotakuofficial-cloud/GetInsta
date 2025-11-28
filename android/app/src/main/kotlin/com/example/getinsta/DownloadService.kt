package com.example.getinsta

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.widget.Toast
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.net.URL

class DownloadService : Service() {
    
    private lateinit var notificationManager: NotificationManager
    private val CHANNEL_ID = "download_channel"
    private val NOTIFICATION_ID = 1001
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val sharedUrl = intent?.getStringExtra("SHARED_URL")
        
        if (sharedUrl != null) {
            // Show download started notification
            showNotification("GetInsta", "Download started...", false)
            
            // Start download in background
            CoroutineScope(Dispatchers.IO).launch {
                downloadInstagramMedia(sharedUrl)
                stopSelf() // Stop service when done
            }
        }
        
        return START_NOT_STICKY
    }
    
    private fun createNotificationChannel() {
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Download Notifications",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Instagram download notifications"
                setSound(null, null)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun showNotification(title: String, content: String, isComplete: Boolean) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(title)
            .setContentText(content)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(isComplete)
            .setOngoing(!isComplete)
            .build()
        
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        if (isComplete) {
            // Auto dismiss after 3 seconds
            CoroutineScope(Dispatchers.Main).launch {
                delay(3000)
                notificationManager.cancel(NOTIFICATION_ID)
            }
        }
    }
    
    private suspend fun downloadInstagramMedia(url: String) {
        try {
            // Fetch Instagram data
            val apiUrl = "https://v1-w3sc.onrender.com/insta/api.php?action=url&url=${java.net.URLEncoder.encode(url, "UTF-8")}"
            val response = URL(apiUrl).readText()
            val data = JSONObject(response)
            
            if (data.getBoolean("success") && data.has("download_links")) {
                val downloadLinks = data.getJSONArray("download_links")
                val caption = data.optString("caption", "instagram media")
                
                // Determine if it's a reel or post
                val isReel = url.contains("/reel/")
                val isPost = url.contains("/p/")
                
                val downloadedFiles = mutableListOf<String>()
                
                if (isReel) {
                    // Reel - single video
                    val downloadUrl = downloadLinks.getString(0)
                    val filename = generateFilename(caption, ".mp4")
                    val filePath = downloadFile(downloadUrl, filename)
                    downloadedFiles.add(filePath)
                } else if (isPost) {
                    // Post - can have multiple images/videos
                    for (i in 0 until downloadLinks.length()) {
                        val downloadUrl = downloadLinks.getString(i)
                        val extension = detectMediaType(downloadUrl)
                        val filename = if (downloadLinks.length() > 1) {
                            generateFilename(caption, extension, i + 1)
                        } else {
                            generateFilename(caption, extension)
                        }
                        val filePath = downloadFile(downloadUrl, filename)
                        downloadedFiles.add(filePath)
                    }
                }
                
                // Show complete notification and toast
                withContext(Dispatchers.Main) {
                    // Save to history
                    saveToHistory(url, caption, data.optString("username", "unknown"), 
                                data.optString("thumbnail", ""), downloadedFiles)
                    
                    showNotification("GetInsta", "Download complete!", true)
                    Toast.makeText(this@DownloadService, "Complete...", Toast.LENGTH_SHORT).show()
                }
            } else {
                withContext(Dispatchers.Main) {
                    showNotification("GetInsta", "Download failed", true)
                    Toast.makeText(this@DownloadService, "Download failed", Toast.LENGTH_SHORT).show()
                }
            }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                showNotification("GetInsta", "Download failed", true)
                Toast.makeText(this@DownloadService, "Download failed", Toast.LENGTH_SHORT).show()
            }
        }
    }
    
    private fun detectMediaType(downloadUrl: String): String {
        return when {
            downloadUrl.contains(".mp4") || downloadUrl.contains("video") -> ".mp4"
            downloadUrl.contains(".jpg") || downloadUrl.contains(".jpeg") -> ".jpg"
            downloadUrl.contains(".png") -> ".png"
            downloadUrl.contains(".webp") -> ".jpg" // Convert webp to jpg
            // Check by content type patterns
            downloadUrl.contains("t51.2885") -> ".jpg" // Instagram image CDN
            downloadUrl.contains("scontent") && downloadUrl.contains("mp4") -> ".mp4"
            downloadUrl.contains("scontent") -> ".jpg" // Default Instagram image
            else -> ".jpg" // Default to image
        }
    }
    
    private fun saveToHistory(url: String, caption: String, username: String, thumbnail: String, filePaths: List<String>) {
        try {
            // Save to app's internal storage (same as Flutter's getApplicationDocumentsDirectory)
            val historyFile = File(filesDir, "download_history.json")
            
            var historyArray = if (historyFile.exists()) {
                org.json.JSONArray(historyFile.readText())
            } else {
                org.json.JSONArray()
            }
            
            // Add each downloaded file to history
            filePaths.forEach { filePath ->
                val filename = File(filePath).name
                
                val downloadItem = JSONObject().apply {
                    put("filename", filename)
                    put("thumbnailUrl", thumbnail)
                    put("videoUrl", url)
                    put("username", username)
                    put("caption", caption)
                    put("filePath", filePath)
                    put("downloadTime", System.currentTimeMillis().toString())
                }
                
                // Add to beginning (most recent first)
                val newArray = org.json.JSONArray()
                newArray.put(downloadItem)
                for (i in 0 until historyArray.length()) {
                    if (i < 49) { // Keep only last 50
                        newArray.put(historyArray.get(i))
                    }
                }
                historyArray = newArray
            }
            
            historyFile.writeText(historyArray.toString())
        } catch (e: Exception) {
            // Ignore history save errors
        }
    }
    
    private suspend fun downloadFile(downloadUrl: String, filename: String): String {
        // Create Downloads/reel directory
        val downloadDir = File("/storage/emulated/0/Download/reel")
        if (!downloadDir.exists()) {
            downloadDir.mkdirs()
        }
        
        // Handle duplicate files
        val finalFile = getUniqueFile(downloadDir, filename)
        
        // Download file
        val inputStream = URL(downloadUrl).openStream()
        val outputStream = FileOutputStream(finalFile)
        
        inputStream.copyTo(outputStream)
        inputStream.close()
        outputStream.close()
        
        return finalFile.absolutePath
    }
    
    private fun generateFilename(caption: String, extension: String, index: Int? = null): String {
        // Clean caption and get first 5 words
        val cleanCaption = caption.replace(Regex("[^a-zA-Z0-9\\s]"), "")
            .replace(Regex("\\s+"), " ")
            .trim()
        
        val words = cleanCaption.split(" ").take(5)
        val name = words.joinToString(" ").lowercase().replace(" ", "_")
        
        val baseName = if (name.isNotEmpty()) name else "instagram_media"
        
        return if (index != null) {
            "${baseName}_${index}${extension}"
        } else {
            "${baseName}${extension}"
        }
    }
    
    private fun getUniqueFile(directory: File, filename: String): File {
        var file = File(directory, filename)
        var counter = 1
        
        while (file.exists()) {
            val nameWithoutExt = filename.substringBeforeLast(".")
            val extension = filename.substringAfterLast(".")
            file = File(directory, "${nameWithoutExt}_${counter}.${extension}")
            counter++
        }
        
        return file
    }
}
