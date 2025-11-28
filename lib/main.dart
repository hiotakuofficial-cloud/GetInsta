import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import 'splash_screen.dart';
import 'screens/history_screen.dart';
import 'services/download_history.dart';

void main() {
  runApp(const GetInstaApp());
}

class GetInstaApp extends StatefulWidget {
  const GetInstaApp({super.key});

  @override
  State<GetInstaApp> createState() => _GetInstaAppState();
}

class _GetInstaAppState extends State<GetInstaApp> {
  static const platform = MethodChannel('com.example.getinsta/share');
  
  @override
  void initState() {
    super.initState();
    _setupShareReceiver();
  }
  
  void _setupShareReceiver() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'handleAutoDownload') {
        final String sharedUrl = call.arguments;
        _startBackgroundDownload(sharedUrl);
      }
    });
  }
  
  void _startBackgroundDownload(String url) async {
    // Show waiting toast
    Fluttertoast.showToast(
      msg: "Waiting...",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
    
    try {
      // Fetch Instagram data
      final response = await http.get(
        Uri.parse('https://v1-w3sc.onrender.com/insta/api.php?action=url&url=${Uri.encodeComponent(url)}'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; InstagramDownloader/1.0)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['download_links'] != null) {
          final downloadUrl = data['download_links'][0];
          final filename = 'instagram_${DateTime.now().millisecondsSinceEpoch}.mp4';
          
          // Start download
          await _downloadFile(downloadUrl, filename);
          
          // Save to history
          await DownloadHistory.addDownload(
            filename: filename,
            thumbnailUrl: data['thumbnail'] ?? '',
            videoUrl: url,
            username: data['username'] ?? 'unknown',
            caption: data['caption'] ?? 'Instagram Media',
            filePath: '/storage/emulated/0/Download/$filename',
          );
          
          // Show complete toast
          Fluttertoast.showToast(
            msg: "Complete...",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Download failed",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }
  
  Future<void> _downloadFile(String url, String filename) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'GetInsta',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF1A1A1A),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/history': (context) => const HistoryScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
