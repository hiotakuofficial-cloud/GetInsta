package com.example.getinsta

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager

class ShareReceiverActivity : Activity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Make it look like a bottom sheet
        window.setFlags(
            WindowManager.LayoutParams.FLAG_DIM_BEHIND,
            WindowManager.LayoutParams.FLAG_DIM_BEHIND
        )
        
        // Handle share intent
        handleShareIntent(intent)
        
        // Show bottom sheet overlay
        showBottomSheetOverlay()
    }
    
    private fun handleShareIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (sharedText != null) {
                // Start main app with bottom sheet
                val mainIntent = Intent(this, MainActivity::class.java).apply {
                    putExtra("SHARED_URL", sharedText)
                    putExtra("SHOW_BOTTOM_SHEET", true)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                startActivity(mainIntent)
                finish()
            }
        }
    }
    
    private fun showBottomSheetOverlay() {
        // This will be handled by MainActivity
    }
}
