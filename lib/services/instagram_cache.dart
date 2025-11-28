import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class InstagramCache {
  static const String _cacheFileName = 'instagram_cache.json';
  
  static Future<String> get _cachePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_cacheFileName';
  }

  static Future<List<Map<String, dynamic>>> getCache() async {
    try {
      final path = await _cachePath;
      final file = File(path);
      
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  static Future<void> addToCache(Map<String, dynamic> postData) async {
    try {
      final cache = await getCache();
      
      // Check if URL already exists
      final existingIndex = cache.indexWhere((item) => item['url'] == postData['url']);
      
      if (existingIndex != -1) {
        // Update existing entry
        cache[existingIndex] = postData;
      } else {
        // Add new entry at beginning
        cache.insert(0, postData);
      }
      
      // Keep only last 20 cached posts
      if (cache.length > 20) {
        cache.removeRange(20, cache.length);
      }
      
      await _saveCache(cache);
    } catch (e) {
      // Error adding to cache - silent fail
    }
  }

  static Future<void> _saveCache(List<Map<String, dynamic>> cache) async {
    try {
      final path = await _cachePath;
      final file = File(path);
      await file.writeAsString(json.encode(cache));
    } catch (e) {
      // Error saving cache - silent fail
    }
  }

  static Future<void> removeFromCache(String url) async {
    try {
      final cache = await getCache();
      cache.removeWhere((item) => item['url'] == url);
      await _saveCache(cache);
    } catch (e) {
      // Error removing from cache - silent fail
    }
  }
}
