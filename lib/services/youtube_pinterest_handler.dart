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
      Fluttertoast.showToast(msg: "🎥 Fetching YouTube info...", backgroundColor: Colors.blue);
      
      final response = await http.get(
        Uri.parse('$youtubeApiBase?action=url&url=$url'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          Fluttertoast.showToast(msg: "✅ YouTube video found!", backgroundColor: Colors.green);
          return {'success': true, 'data': data};
        } else {
          throw Exception(data['error'] ?? 'YouTube API error');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "❌ YouTube Error: $e", backgroundColor: Colors.red, toastLength: Toast.LENGTH_LONG);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> downloadYouTubeVideo(String url, String quality) async {
    try {
      Fluttertoast.showToast(msg: "📹 Getting ${quality}p video link...", backgroundColor: Colors.purple);
      
      final response = await http.get(
        Uri.parse('$youtubeApiBase?action=download&url=$url&q=$quality&type=mp4'),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'downloadUrl': data['download_url'],
            'filename': data['filename'] ?? 'youtube_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
          };
        } else {
          throw Exception(data['error'] ?? 'Video download failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "❌ Video Error: $e", backgroundColor: Colors.red, toastLength: Toast.LENGTH_LONG);
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> downloadYouTubeAudio(String url, String quality) async {
    try {
      Fluttertoast.showToast(msg: "🎵 Getting ${quality}kbps audio link...", backgroundColor: Colors.green);
      
      final response = await http.get(
        Uri.parse('$youtubeApiBase?action=download&url=$url&q=$quality&type=mp3'),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'downloadUrl': data['download_url'],
            'filename': data['filename'] ?? 'youtube_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
          };
        } else {
          throw Exception(data['error'] ?? 'Audio download failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "❌ Audio Error: $e", backgroundColor: Colors.red, toastLength: Toast.LENGTH_LONG);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Quick download functions
  static Future<Map<String, dynamic>> quickDownloadYouTube(String url) async {
    Fluttertoast.showToast(msg: "⚡ Quick YouTube download (360p)...", backgroundColor: Colors.blue);
    return await downloadYouTubeVideo(url, '360');
  }

  static Future<Map<String, dynamic>> quickDownloadPinterest(String url) async {
    try {
      Fluttertoast.showToast(msg: "⚡ Quick Pinterest download...", backgroundColor: Colors.pink);
      
      final result = await getPinterestInfo(url);
      if (result['success'] == true) {
        final data = result['data'];
        final downloadUrl = data['video_url'] ?? data['image_url'];
        final mediaType = data['type'] ?? 'unknown';
        
        String extension = 'jpg';
        if (mediaType == 'video') {
          extension = 'mp4';
        } else if (downloadUrl != null) {
          final uri = Uri.parse(downloadUrl);
          final path = uri.path.toLowerCase();
          if (path.contains('.mp4')) extension = 'mp4';
          else if (path.contains('.webm')) extension = 'webm';
          else if (path.contains('.png')) extension = 'png';
          else if (path.contains('.gif')) extension = 'gif';
          else if (path.contains('.jpeg')) extension = 'jpeg';
        }
        
        return {
          'success': true,
          'downloadUrl': downloadUrl,
          'filename': 'Downloaded From GetInsta By Nehu.$extension',
          'mediaType': mediaType,
          'thumbnail': data['thumbnail'],
          'title': data['title'] ?? 'Pinterest Media',
        };
      } else {
        return result;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "❌ Pinterest Error: $e", backgroundColor: Colors.red, toastLength: Toast.LENGTH_LONG);
      return {'success': false, 'error': e.toString()};
    }
  }

  // Pinterest functions
  static Future<Map<String, dynamic>> getPinterestInfo(String url) async {
    try {
      Fluttertoast.showToast(msg: "📌 Fetching Pinterest info...", backgroundColor: Colors.pink);
      
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
          return {'success': true, 'data': data};
        } else {
          throw Exception('Pinterest API error');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "❌ Pinterest Error: $e", backgroundColor: Colors.red, toastLength: Toast.LENGTH_LONG);
      return {'success': false, 'error': e.toString()};
    }
  }
}
