import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _loadingAnimation;

  @override
  void initState() {
    super.initState();
    
    // Properly hide status bar and navigation bar
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutQuart),
      ),
    );
    
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: Curves.easeInOut,
      ),
    );
    
    _controller.forward();
    _loadingController.repeat();
    _navigateToHome();
  }

  _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      // Restore system UI before navigation
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, _) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 1000),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutQuart,
              ),
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 30,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6C63FF),
                                            Color(0xFF9C88FF),
                                            Color(0xFFB794F6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 60,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFF6C63FF),
                                  Color(0xFF9C88FF),
                                  Color(0xFFB794F6),
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'GetInsta',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Premium Instagram Downloader',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.7),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 60),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _loadingAnimation,
                        builder: (context, child) {
                          return Container(
                            width: 200,
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  width: 200 * _loadingAnimation.value,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6C63FF),
                                        Color(0xFF9C88FF),
                                        Color(0xFFB794F6),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
