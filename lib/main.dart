import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'screens/history_screen.dart';
import 'screens/share_overlay_screen.dart';

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
      if (call.method == 'receiveShare') {
        final String sharedUrl = call.arguments;
        // Navigate to overlay screen
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, _) => ShareOverlayScreen(sharedUrl: sharedUrl),
            transitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (context, animation, _, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
