import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../widgets/modern_components.dart';
import '../utils/animations.dart';

class EnhancedAboutScreen extends StatefulWidget {
  const EnhancedAboutScreen({super.key});

  @override
  State<EnhancedAboutScreen> createState() => _EnhancedAboutScreenState();
}

class _EnhancedAboutScreenState extends State<EnhancedAboutScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 40),
                _buildAppInfo(),
                const SizedBox(height: 30),
                _buildDedicationCard(),
                const SizedBox(height: 24),
                _buildFeaturesList(),
                const SizedBox(height: 24),
                _buildCreditsCard(),
                const SizedBox(height: 24),
                _buildVersionInfo(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInSlide(
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: NeumorphicContainer(
              padding: const EdgeInsets.all(12),
              borderRadius: 14,
              child: const Icon(
                CupertinoIcons.back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'About',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return ScaleInFade(
      delay: const Duration(milliseconds: 200),
      child: GlassmorphicCard(
        child: Column(
          children: [
            PulseAnimation(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'GetInsta',
                  textStyle: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                  speed: const Duration(milliseconds: 150),
                ),
              ],
              isRepeatingAnimation: false,
            ),
            const SizedBox(height: 8),
            Text(
              'Universal Media Downloader',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDedicationCard() {
    return FadeInSlide(
      delay: const Duration(milliseconds: 400),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                CupertinoIcons.heart_fill,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Made with love for',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nehu Singh',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '@yourhoneydewie',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'This app is crafted specially for someone who means the world to me',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    final features = [
      {
        'icon': CupertinoIcons.lightbulb,
        'title': 'Idea & Inspiration',
        'description': 'Nehu Singh gave me the brilliant idea to create this app',
        'color': const Color(0xFFFFB300),
      },
      {
        'icon': CupertinoIcons.rocket,
        'title': 'How to Use',
        'description': 'Share any Instagram, YouTube, or Pinterest link to GetInsta',
        'color': const Color(0xFF6C63FF),
      },
      {
        'icon': CupertinoIcons.checkmark_shield,
        'title': 'Advanced Security',
        'description': 'Enterprise-grade encryption and zero data collection',
        'color': const Color(0xFF4CAF50),
      },
      {
        'icon': CupertinoIcons.download_circle,
        'title': 'Smart Downloads',
        'description': 'Background downloads with progress tracking',
        'color': const Color(0xFFFF5252),
      },
    ];

    return Column(
      children: List.generate(features.length, (index) {
        final feature = features[index];
        return FadeInSlide(
          delay: Duration(milliseconds: 500 + (index * 100)),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: GlassmorphicCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (feature['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: feature['color'] as Color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feature['description'] as String,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCreditsCard() {
    return FadeInSlide(
      delay: const Duration(milliseconds: 900),
      child: GlassmorphicCard(
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.person_circle,
                    color: Color(0xFF6C63FF),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Developer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'PIHU SINGH',
                        style: TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.star_fill,
                        color: Color(0xFFFFB300),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Key Features',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureItem('Multi-platform support (Instagram, YouTube, Pinterest)'),
                  _buildFeatureItem('Background downloads with notifications'),
                  _buildFeatureItem('Advanced video player with controls'),
                  _buildFeatureItem('Smart file naming and organization'),
                  _buildFeatureItem('Download history with search'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF6C63FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionInfo() {
    return FadeInSlide(
      delay: const Duration(milliseconds: 1100),
      child: Column(
        children: [
          NeumorphicContainer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  color: Colors.white.withOpacity(0.7),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Made with Flutter',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
