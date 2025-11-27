import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class HistoryItem {
  final String url;
  final String title;
  final String type; // photo, video, story, album
  final DateTime downloadTime;
  final String filePath;

  HistoryItem({
    required this.url,
    required this.title,
    required this.type,
    required this.downloadTime,
    required this.filePath,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'type': type,
    'downloadTime': downloadTime.toIso8601String(),
    'filePath': filePath,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    url: json['url'],
    title: json['title'],
    type: json['type'],
    downloadTime: DateTime.parse(json['downloadTime']),
    filePath: json['filePath'],
  );
}

class HistoryService {
  static const String _historyFileName = 'download_history.json';
  
  static Future<File> _getHistoryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final historyDir = Directory('${directory.path}/GetInsta/History');
    
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    
    return File('${historyDir.path}/$_historyFileName');
  }

  static Future<List<HistoryItem>> getHistory() async {
    try {
      final file = await _getHistoryFile();
      
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      
      return jsonList.map((json) => HistoryItem.fromJson(json)).toList()
        ..sort((a, b) => b.downloadTime.compareTo(a.downloadTime));
    } catch (e) {
      return [];
    }
  }

  static Future<void> addToHistory(HistoryItem item) async {
    try {
      final history = await getHistory();
      history.insert(0, item);
      
      // Keep only last 100 items
      if (history.length > 100) {
        history.removeRange(100, history.length);
      }
      
      final file = await _getHistoryFile();
      final jsonList = history.map((item) => item.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      // Handle error silently
    }
  }

  static Future<void> clearHistory() async {
    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  static Future<Directory> getDownloadsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${directory.path}/GetInsta/Downloads');
    
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    
    return downloadsDir;
  }
}
