import 'dart:convert';
class ApiConfig {
  // API Base URLs
  static const String baseUrl = 'https://v1-w3sc.onrender.com';
  static const String instagramApi = '$baseUrl/insta/api.php';
  static const String youtubeApi = '$baseUrl/yt/api.php';
  static const String pinterestApi = '$baseUrl/pin/api.php';
  
  // App signature hash for verification
  static const String _appHash = 'afaea552101228848de8f8c7f48a1b7d7a6a042a6094274eaa9d30cb64bf91a7';
  
  // Get verified app token
  static String get apiToken => _appHash;
  
  // Headers
  static Map<String, String> get headers => {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Connection': 'keep-alive',
    'Referer': 'https://www.youtube.com/',
    'Authorization': 'Bearer $apiToken',
  };
  
  // Build API URL with token
  static String buildUrl(String endpoint, Map<String, String> params) {
    params['token'] = apiToken;
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$endpoint?$query';
  }
}
