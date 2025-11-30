package com.example.getinsta

object SecureConfig {
    // App signature hash for verification
    private const val appHash = "afaea552101228848de8f8c7f48a1b7d7a6a042a6094274eaa9d30cb64bf91a7"
    
    // Base URLs for API endpoints
    private const val baseUrl = "https://v1-w3sc.onrender.com"
    
    // Get verified app token
    private fun getAuthKey(): String {
        return appHash
    }
    
    // Build secure API URL with token
    fun buildApiUrl(endpoint: String, params: Map<String, String>): String {
        val token = getAuthKey()
        val allParams = params.toMutableMap()
        allParams["token"] = token
        
        val queryString = allParams.entries.joinToString("&") { (key, value) ->
            "$key=${java.net.URLEncoder.encode(value, "UTF-8")}"
        }
        
        return "$baseUrl/$endpoint?$queryString"
    }
    
    // Get secure headers
    fun getHeaders(): Map<String, String> {
        val token = getAuthKey()
        return mapOf(
            "User-Agent" to "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            "Accept" to "*/*",
            "Accept-Language" to "en-US,en;q=0.9",
            "Accept-Encoding" to "gzip, deflate, br",
            "Connection" to "keep-alive",
            "Referer" to "https://www.youtube.com/",
            "Authorization" to "Bearer $token"
        )
    }
    
    // API endpoints
    object Endpoints {
        const val INSTAGRAM = "insta/api.php"
        const val YOUTUBE = "yt/api.php"
        const val PINTEREST = "pin/api.php"
    }
}
