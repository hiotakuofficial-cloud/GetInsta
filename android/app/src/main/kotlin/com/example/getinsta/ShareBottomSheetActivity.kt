package com.example.getinsta

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.bottomsheet.BottomSheetDialog
import android.view.LayoutInflater
import android.widget.TextView
import android.widget.ImageView
import android.widget.LinearLayout
import android.graphics.Color
import android.view.Gravity
import android.widget.Button
import androidx.core.content.ContextCompat

class ShareBottomSheetActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT) ?: ""
        
        val bottomSheet = BottomSheetDialog(this)
        val view = createBottomSheetView(sharedText)
        bottomSheet.setContentView(view)
        
        bottomSheet.setOnDismissListener {
            finish()
        }
        
        bottomSheet.show()
    }
    
    private fun createBottomSheetView(sharedText: String): LinearLayout {
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(60, 40, 60, 60)
            setBackgroundColor(Color.parseColor("#1E1E1E"))
        }
        
        // Header with logo and title
        val headerLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        
        val logo = ImageView(this).apply {
            layoutParams = LinearLayout.LayoutParams(120, 120).apply {
                setMargins(0, 0, 40, 0)
            }
            setImageResource(R.mipmap.ic_launcher)
            scaleType = ImageView.ScaleType.CENTER_CROP
        }
        
        val titleLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
        }
        
        val title = TextView(this).apply {
            text = "GetInsta"
            textSize = 24f
            setTextColor(Color.WHITE)
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        
        val subtitle = TextView(this).apply {
            text = "Download Instagram Content"
            textSize = 14f
            setTextColor(Color.parseColor("#6C63FF"))
        }
        
        titleLayout.addView(title)
        titleLayout.addView(subtitle)
        headerLayout.addView(logo)
        headerLayout.addView(titleLayout)
        
        // URL display
        val urlText = TextView(this).apply {
            text = if (sharedText.isNotEmpty()) sharedText else "No URL shared"
            textSize = 16f
            setTextColor(Color.parseColor("#CCCCCC"))
            setPadding(40, 60, 40, 40)
            setBackgroundColor(Color.parseColor("#2A2A2A"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 40, 0, 40)
            }
        }
        
        // Download button
        val downloadBtn = Button(this).apply {
            text = "Download Now"
            textSize = 16f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#6C63FF"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                140
            )
            setOnClickListener {
                // Open main app
                val intent = Intent(this@ShareBottomSheetActivity, MainActivity::class.java)
                intent.putExtra("shared_url", sharedText)
                startActivity(intent)
                finish()
            }
        }
        
        layout.addView(headerLayout)
        layout.addView(urlText)
        layout.addView(downloadBtn)
        
        return layout
    }
}
