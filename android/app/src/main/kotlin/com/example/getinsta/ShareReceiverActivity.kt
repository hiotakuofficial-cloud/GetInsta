package com.example.getinsta

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.Toast

class ShareReceiverActivity : Activity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        handleShareIntent(intent)
        finish() // Close immediately
    }
    
    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedUrl = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (sharedUrl != null) {
                // Show waiting toast
                Toast.makeText(this, "Waiting...", Toast.LENGTH_SHORT).show()
                
                // Start main app in background with download
                val mainIntent = Intent(this, MainActivity::class.java).apply {
                    putExtra("SHARED_URL", sharedUrl)
                    putExtra("AUTO_DOWNLOAD", true)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(mainIntent)
            }
        }
    }
}
