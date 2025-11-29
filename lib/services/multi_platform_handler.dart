import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

class MultiPlatformHandler {
  static const String youtubeApiBase = 'https://v1-w3sc.onrender.com/yt/api.php';
  static const String pinterestApiBase = 'https://v1-w3sc.onrender.com/pin/api.php';

  // Platform detection
  static bool isYouTubeUrl(String url) {
    return url.contains('youtube.com') || 
           url.contains('youtu.be') || 
           url.contains('m.youtube.com');
  }

  static bool isPinterestUrl(String url) {
    return url.contains('pinterest.com') || 
           url.contains('pin.it');
  }

  static String detectPlatform(String url) {
    if (isYouTubeUrl(url)) return 'youtube';
    if (isPinterestUrl(url)) return 'pinterest';
    return 'instagram';
  }

  // YouTube API calls
  static Future<Map<String, dynamic>> getYouTubeInfo(String url) async {
    try {
      Fluttertoast.showToast(msg: "🔍 Fetching YouTube info...");
      
      final response = await http.get(
        Uri.parse('$youtubeApiBase?action=url&url=$url'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          Fluttertoast.showToast(msg: "✅ YouTube video found!", backgroundColor: Colors.green);
          return {'success': true, 'data': data, 'platform': 'youtube'};
        } else {
          throw Exception(data['error'] ?? 'YouTube API error');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "❌ YouTube Error: $e", backgroundColor: Colors.red);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> downloadYouTubeVideo(String url, String quality) async {
    try {
      Fluttertoast.showToast(msg: "⬇️ Getting YouTube download link...");
      
      final response = await http.get(
        Uri.parse('$youtubeApiBase?action=download&url=$url&q=$quality&type=mp4'),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'downloadUrl': data['download_url'],
            'filename': data['filename'] ?? 'youtube_${quality}p_${DateTime.now().millisecondsSinceEpoch}.mp4',
            'platform': 'youtube'
          };
        } else {
          throw Exception(data['error'] ?? 'Download API error');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "❌ YouTube Download Error: $e", backgroundColor: Colors.red);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Pinterest API calls
  static Future<Map<String, dynamic>> getPinterestInfo(String url) async {
    try {
      Fluttertoast.showToast(msg: "🔍 Fetching Pinterest info...");
      
      final response = await http.get(
        Uri.parse('$pinterestApiBase?action=url&url=$url'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        String responseBody = response.body;
        
        // Handle PHP warnings
        if (responseBody.contains('<br />')) {
          final jsonStart = responseBody.indexOf('{');
          if (jsonStart != -1) {
            responseBody = responseBody.substring(jsonStart);
          }
        }
        
        final data = json.decode(responseBody);
        if (data['success'] == true) {
          Fluttertoast.showToast(msg: "✅ Pinterest media found!", backgroundColor: Colors.green);
          return {'success': true, 'data': data, 'platform': 'pinterest'};
        } else {
          throw Exception('Pinterest API returned success: false');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "❌ Pinterest Error: $e", backgroundColor: Colors.red);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Unified processing function
  static Future<Map<String, dynamic>> processUrl(String url) async {
    final platform = detectPlatform(url);
    
    Fluttertoast.showToast(
      msg: "🔍 Detected: ${platform.toUpperCase()}", 
      backgroundColor: platform == 'youtube' ? Colors.red : 
                     platform == 'pinterest' ? Colors.pink : Colors.purple
    );

    switch (platform) {
      case 'youtube':
        return await getYouTubeInfo(url);
      case 'pinterest':
        return await getPinterestInfo(url);
      default:
        return {'success': false, 'error': 'Unsupported platform', 'platform': platform};
    }
  }

  // Quality options for YouTube
  static List<Map<String, String>> getYouTubeQualities() {
    return [
      {'quality': '720', 'label': '720p HD'},
      {'quality': '480', 'label': '480p'},
      {'quality': '360', 'label': '360p'},
    ];
  }
}
