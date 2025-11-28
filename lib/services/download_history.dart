import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DownloadHistory {
  static const String _historyFileName = 'download_history.json';
  
  static Future<String> get _historyPath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_historyFileName';
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final path = await _historyPath;
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

  static Future<void> addDownload({
    required String filename,
    required String thumbnailUrl,
    required String videoUrl,
    required String username,
    required String caption,
    required String filePath,
  }) async {
    try {
      final history = await getHistory();
      
      final downloadItem = {
        'filename': filename,
        'thumbnailUrl': thumbnailUrl,
        'videoUrl': videoUrl,
        'username': username,
        'caption': caption,
        'filePath': filePath,
        'downloadTime': DateTime.now().toIso8601String(),
      };
      
      // Add to beginning of list (most recent first)
      history.insert(0, downloadItem);
      
      // Keep only last 50 downloads
      if (history.length > 50) {
        history.removeRange(50, history.length);
      }
      
      await _saveHistory(history);
    } catch (e) {
    }
  }

  static Future<void> _saveHistory(List<Map<String, dynamic>> history) async {
    try {
      final path = await _historyPath;
      final file = File(path);
      await file.writeAsString(json.encode(history));
    } catch (e) {
      // Error saving history - silent fail
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentDownloads({int limit = 20}) async {
    final history = await getHistory();
    return history.take(limit).toList();
  }

  static Future<void> removeDownload(String filename) async {
    try {
      final history = await getHistory();
      history.removeWhere((item) => item['filename'] == filename);
      await _saveHistory(history);
      Fluttertoast.showToast(msg: "Removed from history");
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to remove from history");
    }
  }

  static Future<List<Map<String, dynamic>>> getDownloadsFromFolder() async {
    try {
      final directory = Directory('/storage/emulated/0/Download/reel');
      if (!await directory.exists()) {
        return [];
      }
      
      final files = await directory.list().toList();
      final videoFiles = files.where((file) => 
        file.path.endsWith('.mp4') || 
        file.path.endsWith('.jpg') || 
        file.path.endsWith('.png')
      ).toList();
      
      final List<Map<String, dynamic>> folderDownloads = [];
      
      for (var file in videoFiles) {
        final stat = await file.stat();
        folderDownloads.add({
          'filename': file.path.split('/').last,
          'filePath': file.path,
          'downloadTime': stat.modified.toIso8601String(),
          'size': '${(stat.size / 1024 / 1024).toStringAsFixed(2)} MB',
        });
      }
      
      // Sort by modification time (newest first)
      folderDownloads.sort((a, b) => 
        DateTime.parse(b['downloadTime']).compareTo(DateTime.parse(a['downloadTime']))
      );
      
      return folderDownloads;
    } catch (e) {
      return [];
    }
  }
}
