import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

class SystemOverlayScreen extends StatefulWidget {
  final String sharedUrl;

  const SystemOverlayScreen({super.key, required this.sharedUrl});

  @override
  State<SystemOverlayScreen> createState() => _SystemOverlayScreenState();
}

class _SystemOverlayScreenState extends State<SystemOverlayScreen>
    with TickerProviderStateMixin {
  static const platform = MethodChannel('com.example.getinsta/share');
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  String _thumbnailUrl = '';
  String _title = 'Loading...';
  bool _isLoading = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Start animations
    _fadeController.forward();
    _slideController.forward();
    
    // Fetch Instagram data
    _fetchInstagramData();
    
    // Listen for method calls
    platform.setMethodCallHandler((call) async {
      if (call.method == 'showOverlay') {
        // Already showing
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchInstagramData() async {
    try {
      final response = await http.get(
        Uri.parse('https://v1-w3sc.onrender.com/insta/api.php?url=${Uri.encodeComponent(widget.sharedUrl)}'),
        headers: {'User-Agent': 'Mozilla/5.0 (compatible; InstagramDownloader/1.0)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'success' && data['data'] != null) {
          final mediaData = data['data'];
          
          if (mediaData is List && mediaData.isNotEmpty) {
            final mediaItem = mediaData[0];
            
            setState(() {
              _thumbnailUrl = mediaItem['thumbnail'] ?? '';
              _title = mediaItem['caption'] ?? 'Instagram Media';
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _title = 'Instagram Media';
        _isLoading = false;
      });
    }
  }

  void _startDownload() async {
    setState(() {
      _isDownloading = true;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Show toast
    Fluttertoast.showToast(
      msg: "Downloading...",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
    
    // Close overlay after short delay
    await Future.delayed(const Duration(milliseconds: 800));
    _closeOverlay();
  }

  void _closeOverlay() async {
    // Animate out
    await _slideController.reverse();
    await _fadeController.reverse();
    
    // Close via platform
    try {
      await platform.invokeMethod('closeOverlay');
    } catch (e) {
      // Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Container(
            color: Colors.black.withOpacity(0.5 * _fadeAnimation.value),
            child: GestureDetector(
              onTap: _closeOverlay,
              child: Stack(
                children: [
                  // Blur effect
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 10.0 * _fadeAnimation.value,
                      sigmaY: 10.0 * _fadeAnimation.value,
                    ),
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                  
                  // Bottom sheet
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: GestureDetector(
                        onTap: () {}, // Prevent closing when tapping sheet
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 20,
                                spreadRadius: 0,
                                offset: Offset(0, -5),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Handle bar
                                Container(
                                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                
                                // Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.download_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Quick Download',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              'GetInsta',
                                              style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Content
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    children: [
                                      // Thumbnail
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2A2A2A),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: _thumbnailUrl.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.network(
                                                  _thumbnailUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return const Icon(
                                                      Icons.image,
                                                      color: Color(0xFF6C63FF),
                                                      size: 32,
                                                    );
                                                  },
                                                ),
                                              )
                                            : const Icon(
                                                Icons.image,
                                                color: Color(0xFF6C63FF),
                                                size: 32,
                                              ),
                                      ),
                                      
                                      const SizedBox(width: 16),
                                      
                                      // Title
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _isLoading ? 'Loading...' : _title,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Instagram Media',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // Buttons
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Row(
                                    children: [
                                      // Cancel button
                                      Expanded(
                                        child: Container(
                                          height: 52,
                                          child: ElevatedButton(
                                            onPressed: _closeOverlay,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2A2A2A),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 12),
                                      
                                      // Download button
                                      Expanded(
                                        child: Container(
                                          height: 52,
                                          child: ElevatedButton(
                                            onPressed: _isDownloading ? null : _startDownload,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF6C63FF),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: _isDownloading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  )
                                                : const Text(
                                                    'Download',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
