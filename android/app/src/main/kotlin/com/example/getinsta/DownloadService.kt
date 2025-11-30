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
            // Start as foreground service for Android 15
            startForeground(NOTIFICATION_ID, createInitialNotification())
            
            // Start download in background
            CoroutineScope(Dispatchers.IO).launch {
                downloadInstagramMedia(sharedUrl)
                stopForeground(true) // Remove foreground notification
                stopSelf() // Stop service when done
            }
        } else {
            Toast.makeText(this, "Service: No URL received", Toast.LENGTH_SHORT).show()
        }
        
        return START_NOT_STICKY
    }
    
    private fun createInitialNotification(): android.app.Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("GetInsta")
            .setContentText("Download started...")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
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
            // Show processing notification
            withContext(Dispatchers.Main) {
                showNotification("GetInsta", "Processing URL...", false)
            }
            
            // Detect platform and handle accordingly
            when {
                isYouTubeUrl(url) -> downloadYouTubeMedia(url)
                isPinterestUrl(url) -> {
                    withContext(Dispatchers.Main) {
                        showNotification("GetInsta", "Pinterest: Use main app", true)
                        Toast.makeText(this@DownloadService, "Pinterest: Use main app for downloads", Toast.LENGTH_LONG).show()
                    }
                }
                else -> downloadInstagramMediaOriginal(url)
            }
            
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                showNotification("GetInsta", "Download failed: ${e.message}", true)
                Toast.makeText(this@DownloadService, "Error: ${e.message}", Toast.LENGTH_LONG).show()
            }
        }
    }
    
    private fun isYouTubeUrl(url: String): Boolean {
        return url.contains("youtube.com") || url.contains("youtu.be") || url.contains("m.youtube.com")
    }
    
    private fun isPinterestUrl(url: String): Boolean {
        return url.contains("pinterest.com") || url.contains("pin.it")
    }
    
    private suspend fun downloadYouTubeMedia(url: String) {
        try {
            withContext(Dispatchers.Main) {
                showNotification("GetInsta", "Getting YouTube video...", false)
            }
            
            // Build secure API URL with token
            val apiUrl = SecureConfig.buildApiUrl(SecureConfig.Endpoints.YOUTUBE, mapOf(
                "action" to "download",
                "url" to url,
                "q" to "360",
                "type" to "mp4"
            ))
            
            val connection = URL(apiUrl).openConnection()
            
            // Add secure headers
            SecureConfig.getHeaders().forEach { (key, value) ->
                connection.setRequestProperty(key, value)
            }
            
            // Override compression for YouTube API
            connection.setRequestProperty("Accept-Encoding", "identity")
            
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            
            val response = connection.getInputStream().bufferedReader().readText()
            val data = JSONObject(response)
            
            if (data.getBoolean("success")) {
                val downloadUrl = data.getString("download_url")
                val filename = data.optString("filename", "youtube_video.mp4")
                
                withContext(Dispatchers.Main) {
                    showNotification("GetInsta", "Downloading...", false)
                }
                
                downloadFileWithHeaders(downloadUrl, filename)
                
                withContext(Dispatchers.Main) {
                    showNotification("GetInsta", "YouTube Complete!", true)
                    Toast.makeText(this@DownloadService, "YouTube Complete!", Toast.LENGTH_SHORT).show()
                }
            } else {
                throw Exception("API failed")
            }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                showNotification("GetInsta", "YouTube Failed", true)
                Toast.makeText(this@DownloadService, "YouTube Failed", Toast.LENGTH_SHORT).show()
            }
        }
    }

    private suspend fun getActualFileExtension(downloadUrl: String): String {
        return withContext(Dispatchers.IO) {
            try {
                val connection = URL(downloadUrl).openConnection()
                connection.setRequestProperty("User-Agent", "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36")
                connection.setRequestProperty("Accept", "*/*")
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                
                // Cast to HttpURLConnection to set request method
                if (connection is java.net.HttpURLConnection) {
                    connection.requestMethod = "HEAD"
                }
                
                connection.connect()
                val contentType = connection.contentType?.lowercase() ?: ""
                val contentDisposition = connection.getHeaderField("Content-Disposition")?.lowercase() ?: ""
                
                // Check content-disposition first for filename hints
                if (contentDisposition.contains(".mp4") || contentDisposition.contains(".webm")) {
                    return@withContext ".mp4"
                }
                if (contentDisposition.contains(".jpg") || contentDisposition.contains(".jpeg")) {
                    return@withContext ".jpg"
                }
                if (contentDisposition.contains(".png")) {
                    return@withContext ".png"
                }
                if (contentDisposition.contains(".gif")) {
                    return@withContext ".gif"
                }
                
                // Then check content-type
                when {
                    contentType.contains("video/mp4") || contentType.contains("video/webm") -> ".mp4"
                    contentType.contains("video/") -> ".mp4"
                    contentType.contains("image/png") -> ".png"
                    contentType.contains("image/gif") -> ".gif"
                    contentType.contains("image/jpeg") || contentType.contains("image/jpg") -> ".jpg"
                    contentType.contains("image/") -> ".jpg"
                    // Fallback: check URL path
                    downloadUrl.contains(".mp4") -> ".mp4"
                    downloadUrl.contains(".webm") -> ".mp4"
                    downloadUrl.contains(".png") -> ".png"
                    downloadUrl.contains(".gif") -> ".gif"
                    else -> ".jpg" // default fallback for images
                }
            } catch (e: Exception) {
                // If HEAD request fails, try to guess from URL
                when {
                    downloadUrl.contains(".mp4") || downloadUrl.contains("video") -> ".mp4"
                    downloadUrl.contains(".png") -> ".png"
                    downloadUrl.contains(".gif") -> ".gif"
                    else -> ".jpg"
                }
            }
        }
    }
    
    private suspend fun downloadInstagramMediaOriginal(url: String) {
        try {
            // Build secure API URL with token
            val apiUrl = SecureConfig.buildApiUrl(SecureConfig.Endpoints.INSTAGRAM, mapOf(
                "action" to "url",
                "url" to url
            ))
            
            val connection = URL(apiUrl).openConnection()
            
            // Add secure headers
            SecureConfig.getHeaders().forEach { (key, value) ->
                connection.setRequestProperty(key, value)
            }
            
            // Override compression for Instagram API
            connection.setRequestProperty("Accept-Encoding", "identity")
            
            val response = connection.getInputStream().bufferedReader().readText()
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
    
    private suspend fun downloadFileWithHeaders(downloadUrl: String, filename: String): String {
        return withContext(Dispatchers.IO) {
            val connection = URL(downloadUrl).openConnection()
            
            // Add secure headers
            SecureConfig.getHeaders().forEach { (key, value) ->
                connection.setRequestProperty(key, value)
            }
            
            // Override specific headers for downloads
            connection.setRequestProperty("Accept-Encoding", "identity")
            
            // Add specific referer based on URL
            when {
                downloadUrl.contains("youtube") || downloadUrl.contains("yt-dl") -> {
                    connection.setRequestProperty("Referer", "https://www.youtube.com/")
                }
                downloadUrl.contains("pinterest") || downloadUrl.contains("pinsave") -> {
                    connection.setRequestProperty("Referer", "https://www.pinterest.com/")
                }
            }
            
            connection.connectTimeout = 30000
            connection.readTimeout = 30000
            
            val inputStream = connection.getInputStream()
            
            val downloadsDir = File("/storage/emulated/0/Download/reel")
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            
            val file = getUniqueFile(downloadsDir, filename)
            val outputStream = FileOutputStream(file)
            
            inputStream.copyTo(outputStream)
            
            inputStream.close()
            outputStream.close()
            
            file.absolutePath
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
