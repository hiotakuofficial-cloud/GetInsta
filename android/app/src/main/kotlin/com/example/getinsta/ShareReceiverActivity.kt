package com.example.getinsta

import android.app.Activity
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import kotlinx.coroutines.*
import org.json.JSONObject
import java.net.URL

class ShareReceiverActivity : Activity() {
    
    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check overlay permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            startActivity(intent)
            finish()
            return
        }
        
        handleShareIntent(intent)
    }
    
    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedUrl = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (sharedUrl != null) {
                showOverlayBottomSheet(sharedUrl)
            }
        }
    }
    
    private fun showOverlayBottomSheet(url: String) {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        // Create overlay view
        overlayView = LayoutInflater.from(this).inflate(R.layout.overlay_bottom_sheet, null)
        
        // Setup window params for bottom sheet overlay
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_DIM_BEHIND,
            PixelFormat.TRANSLUCENT
        )
        
        params.gravity = Gravity.BOTTOM
        params.dimAmount = 0.5f
        
        // Add overlay to window
        windowManager.addView(overlayView, params)
        
        // Setup UI
        setupOverlayUI(url)
        
        // Finish activity but keep overlay
        finish()
    }
    
    private fun setupOverlayUI(url: String) {
        val thumbnail = overlayView?.findViewById<ImageView>(R.id.thumbnail)
        val titleText = overlayView?.findViewById<TextView>(R.id.title)
        val downloadBtn = overlayView?.findViewById<Button>(R.id.downloadBtn)
        val cancelBtn = overlayView?.findViewById<Button>(R.id.cancelBtn)
        
        // Fetch Instagram data
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val response = URL("https://v1-w3sc.onrender.com/insta/api.php?url=$url").readText()
                val json = JSONObject(response)
                
                if (json.getString("status") == "success") {
                    val data = json.getJSONArray("data").getJSONObject(0)
                    val thumbnailUrl = data.getString("thumbnail")
                    val title = data.optString("caption", "Instagram Media")
                    
                    runOnUiThread {
                        titleText?.text = title
                        // Load thumbnail (you'll need Glide or similar)
                        // Glide.with(this@ShareReceiverActivity).load(thumbnailUrl).into(thumbnail)
                    }
                }
            } catch (e: Exception) {
                runOnUiThread {
                    titleText?.text = "Instagram Media"
                }
            }
        }
        
        // Download button
        downloadBtn?.setOnClickListener {
            Toast.makeText(this, "Downloading...", Toast.LENGTH_SHORT).show()
            // Start download service
            closeOverlay()
        }
        
        // Cancel button
        cancelBtn?.setOnClickListener {
            closeOverlay()
        }
    }
    
    private fun closeOverlay() {
        overlayView?.let {
            windowManager.removeView(it)
        }
    }
}
