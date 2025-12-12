import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'screens/enhanced_history_screen.dart';
import 'screens/professional_video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const GetInstaApp());
}

class GetInstaApp extends StatefulWidget {
  const GetInstaApp({super.key});

  @override
  State<GetInstaApp> createState() => _GetInstaAppState();
}

class _GetInstaAppState extends State<GetInstaApp> {
  static const platform = MethodChannel('com.example.getinsta/video_intent');
  bool _hasExternalVideo = false;
  String? _externalVideoPath;

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
          _hasExternalVideo = true;
          _externalVideoPath = videoPath;
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
      home: _hasExternalVideo && _externalVideoPath != null
          ? ProfessionalVideoPlayer(
              videoPath: _externalVideoPath!,
              title: 'External Video',
            )
          : const SplashScreen(),
      routes: {
        '/history': (context) => const EnhancedHistoryScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
