import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';
import 'screens/history_screen.dart';
import 'screens/system_overlay_screen.dart';

void main() {
  runApp(const GetInstaApp());
}

class GetInstaApp extends StatefulWidget {
  const GetInstaApp({super.key});

  @override
  State<GetInstaApp> createState() => _GetInstaAppState();
}

class _GetInstaAppState extends State<GetInstaApp> {
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
        '/system_overlay': (context) => const SystemOverlayScreen(sharedUrl: ''),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/system_overlay') {
          final args = settings.arguments as String?;
          return MaterialPageRoute(
            builder: (context) => SystemOverlayScreen(sharedUrl: args ?? ''),
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
