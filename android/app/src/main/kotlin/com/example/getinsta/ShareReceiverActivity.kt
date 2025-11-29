package com.example.getinsta

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import android.widget.Toast

class ShareReceiverActivity : Activity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Set window flags to prevent small window error
        window.setFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
        )
        
        // Handle share intent immediately
        handleShareIntent(intent)
        
        // Finish immediately - no UI shown
        finish()
    }
    
    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedUrl = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (sharedUrl != null) {
                // Debug toast to see received URL
                Toast.makeText(this, "Received: ${sharedUrl.take(50)}...", Toast.LENGTH_LONG).show()
                
                // Start background service - NO activity launch
                val serviceIntent = Intent(this, DownloadService::class.java).apply {
                    putExtra("SHARED_URL", sharedUrl)
                }
                startService(serviceIntent)
            } else {
                Toast.makeText(this, "No URL received", Toast.LENGTH_SHORT).show()
            }
        } else {
            Toast.makeText(this, "Invalid share intent", Toast.LENGTH_SHORT).show()
        }
    }
}
