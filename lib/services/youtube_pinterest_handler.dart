import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

class YouTubePinterestHandler {
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

  // YouTube functions
  static Future<Map<String, dynamic>> getYouTubeInfo(String url) async {
    try {
      Fluttertoast.showToast(msg: "🔍 Fetching YouTube info...");
      
      final response = await http.get(
        Uri.parse('$youtubeApiBase?action=url&url=$url'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {'success': true, 'data': data};
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
      final response = await http.get(
        Uri.parse('$youtubeApiBase?action=download&url=$url&q=$quality&type=mp4'),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'downloadUrl': data['download_url'],
            'filename': data['filename'] ?? 'youtube_${quality}p.mp4',
          };
        } else {
          throw Exception(data['error'] ?? 'Download failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> downloadYouTubeAudio(String url, String quality) async {
    try {
      final response = await http.get(
        Uri.parse('$youtubeApiBase?action=download&url=$url&q=$quality&type=mp3'),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'downloadUrl': data['download_url'],
            'filename': data['filename'] ?? 'youtube_${quality}kbps.mp3',
          };
        } else {
          throw Exception(data['error'] ?? 'Download failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Pinterest functions
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
          return {'success': true, 'data': data};
        } else {
          throw Exception('Pinterest API error');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "❌ Pinterest Error: $e", backgroundColor: Colors.red);
      return {'success': false, 'error': e.toString()};
    }
  }
}
