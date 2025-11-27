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
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
