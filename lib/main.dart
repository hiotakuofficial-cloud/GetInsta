import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'screens/history_screen.dart';
import 'screens/professional_video_player.dart';

void main() {
  runApp(const GetInstaApp());
}

class GetInstaApp extends StatefulWidget {
  const GetInstaApp({super.key});

  @override
  State<GetInstaApp> createState() => _GetInstaAppState();
}

class _GetInstaAppState extends State<GetInstaApp> {
  static const platform = MethodChannel('com.example.getinsta/video_intent');

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'openVideo') {
        final String videoPath = call.arguments;
        _openVideoPlayer(videoPath);
      }
    });
  }

  void _openVideoPlayer(String videoPath) {
    print('Opening video: $videoPath'); // Debug log
    
    // Navigate to video player with the real file path
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ProfessionalVideoPlayer(
          videoPath: videoPath,
          title: 'External Video',
        ),
      ),
    );
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
