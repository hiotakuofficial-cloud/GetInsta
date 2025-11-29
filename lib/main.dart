import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'screens/history_screen.dart';
import 'screens/professional_video_player.dart';
import 'screens/simple_music_player.dart';

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
  bool _hasExternalMedia = false;
  String? _externalMediaPath;
  bool _isAudio = false;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    print('Setting up method channel...');
    platform.setMethodCallHandler((call) async {
      print('Method channel call received: ${call.method}');
      print('Arguments: ${call.arguments}');
      
      if (call.method == 'openVideo') {
        final String videoPath = call.arguments;
        print('Opening video: $videoPath');
        
        setState(() {
          _hasExternalMedia = true;
          _externalMediaPath = videoPath;
          _isAudio = false;
        });
      } else if (call.method == 'openAudio') {
        final String audioPath = call.arguments;
        print('Opening audio: $audioPath');
        
        setState(() {
          _hasExternalMedia = true;
          _externalMediaPath = audioPath;
          _isAudio = true;
        });
      }
    });
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
      home: _hasExternalMedia && _externalMediaPath != null
          ? _isAudio
              ? SimpleMusicPlayer(
                  audioPath: _externalMediaPath!,
                  title: 'External Audio',
                )
              : ProfessionalVideoPlayer(
                  videoPath: _externalMediaPath!,
                  title: 'External Video',
                )
          : const SplashScreen(),
      routes: {
        '/history': (context) => const HistoryScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
