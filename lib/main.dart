import 'package:flutter/material.dart';
import 'splash_screen.dart';

void main() {
  runApp(const GetInstaApp());
}

class GetInstaApp extends StatelessWidget {
  const GetInstaApp({super.key});

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
      debugShowCheckedModeBanner: false,
    );
  }
}
