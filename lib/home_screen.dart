import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _pasteController;
  late AnimationController _searchController2;
  late AnimationController _dragController;
  late Animation<double> _pasteAnimation;
  late Animation<double> _searchAnimation;
  late Animation<Offset> _dragAnimation;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Transparent status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    _pasteController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _searchController2 = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _dragController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pasteAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _pasteController, curve: Curves.elasticOut),
    );

    _searchAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _searchController2, curve: Curves.elasticOut),
    );

    _dragAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(-1.0, 0.0)).animate(
      CurvedAnimation(parent: _dragController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pasteController.dispose();
    _searchController2.dispose();
    _dragController.dispose();
    super.dispose();
  }

  void _onPastePressed() async {
    _pasteController.forward().then((_) {
      _pasteController.reverse();
    });
    
    ClipboardData? data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null) {
      _searchController.text = data.text!;
      _searchController2.forward().then((_) {
        _searchController2.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main Home Screen
          SlideTransition(
            position: _dragAnimation,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragOffset += details.delta.dx;
                  if (_dragOffset < 0) {
                    _dragController.value = (-_dragOffset / MediaQuery.of(context).size.width).clamp(0.0, 1.0);
                  }
                });
              },
              onHorizontalDragEnd: (details) {
                if (_dragOffset < -100 || details.primaryVelocity! < -500) {
                  // Complete the transition to history
                  _dragController.forward().then((_) {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => const HistoryScreen(),
                        transitionDuration: Duration.zero,
                      ),
                    ).then((_) {
                      _dragController.reset();
                      _dragOffset = 0.0;
                    });
                  });
                } else {
                  // Snap back to original position
                  _dragController.reverse();
                  _dragOffset = 0.0;
                }
              },
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.delayed(const Duration(seconds: 1));
                },
                color: const Color(0xFF6C63FF),
                backgroundColor: const Color(0xFF1E1E1E),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                    child: Column(
                      children: [
                        // Header
                        Row(
                          children: [
                            // Left Logo
                            Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: 45,
                                  height: 45,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Center Title
                            Expanded(
                              child: Center(
                                child: Text(
                                  'GetInsta',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontFamily: 'Cursive',
                                    letterSpacing: 1.2,
                                    shadows: [
                                      Shadow(
                                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Right Follow Button
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Follow',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Search Bar
                        AnimatedBuilder(
                          animation: _searchAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _searchAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF6C63FF).withOpacity(0.4),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                                      blurRadius: 25,
                                      spreadRadius: 0,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF6C63FF).withOpacity(0.1),
                                      blurRadius: 50,
                                      spreadRadius: 5,
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      offset: const Offset(0, 8),
                                      blurRadius: 16,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Left Search Icon
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 12),
                                      child: Icon(
                                        Icons.search_rounded,
                                        color: const Color(0xFF6C63FF).withOpacity(0.7),
                                        size: 24,
                                      ),
                                    ),
                                    
                                    // Search Input
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Paste Instagram URL here...',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 16,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                        ),
                                      ),
                                    ),
                                    
                                    // Paste Button
                                    GestureDetector(
                                      onTap: _onPastePressed,
                                      child: AnimatedBuilder(
                                        animation: _pasteAnimation,
                                        builder: (context, child) {
                                          return Transform.scale(
                                            scale: _pasteAnimation.value,
                                            child: Container(
                                              margin: const EdgeInsets.only(right: 12),
                                              padding: const EdgeInsets.all(12),
                                              child: const Icon(
                                                Icons.content_paste_rounded,
                                                color: Color(0xFF6C63FF),
                                                size: 20,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        
                        Center(
                          child: Text(
                            'Paste Instagram URL to start downloading',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // History Screen Preview
          if (_dragController.value > 0)
            Positioned(
              left: MediaQuery.of(context).size.width * (1 - _dragController.value),
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width,
              child: const HistoryScreen(),
            ),
        ],
      ),
    );
  }
}
